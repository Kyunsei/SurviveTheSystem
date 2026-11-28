class_name PilotSystem
extends Node
## Every controlled agent (Pilot): solo, several players, or network players later.
##
## Runs right BEFORE each simulation tick (SimulationManager calls between_ticks), when the
## species arrays are free, also in pipelined mode:
##   1. reads each pilot's input (local: pilot.poll, network: receive_input)
##   2. does its ACTIONS on the main thread: pick up, drop, throw, eat, attack, use, interact,
##      dash, jump buffer. The species decides which actions it has (species.control_actions)
##      and can replace any of them (species.on_control_action).
##   3. the MOVEMENT is done by the species in its chunk tick: species.get_pilot(i) and
##      species.control_velocity(pilot, ...) (speed, jump... are per species).
##
## Only the authority applies inputs: solo, or the host (multiplayer.is_server()).
## Created automatically by PlayerController (as a child of AlifeManager named "Pilots").
## Add it to the scene yourself to change its settings in the inspector.

signal pilot_added(pilot: Pilot)
signal pilot_removed(pilot: Pilot)            # released, or the agent died / disappeared
signal picked_up(pilot: Pilot, item_species, item_index: int)
signal dropped(pilot: Pilot, item_species, item_index: int)
signal thrown(pilot: Pilot, item_species, item_index: int, speed: float)
signal item_landed(item_species, item_index: int, position: Vector3)
## hits: Array of [species, local_index] that were inside the box
signal attacked(pilot: Pilot, hits: Array)
signal dashed(pilot: Pilot)
signal ate(pilot: Pilot, food_species, food_index: int)

@export var alifemanager: AlifeManager

@export_group("Targets")
@export var target_range := 3.0               # max distance for the outlined / pick-up target
@export var target_search_rings := 2          # grid rings searched for the closest agent

@export_group("Jump")
@export var jump_buffer_time := 0.12          # a jump pressed this early before landing still counts

@export_group("Throw")
@export var throw_min_speed := 3.0            # tap throw
@export var throw_max_speed := 14.0           # throw held for throw_charge_time
@export var throw_charge_time := 1.0          # seconds to reach full power
@export var throw_angle_deg := 35.0           # launch angle above the ground
@export var throw_gravity := 20.0             # world units / s²
@export var ground_y := 0.0                   # where thrown items land

@export_group("Eat")
@export var eat_hold_time := 1.0              # seconds eat must be held before eating

@export_group("Carrying players")
## Agents played by someone (other players) can be picked up, carried and thrown.
@export var carry_players := true
## A carried player breaks free after pressing jump this many times (0 = never).
@export var break_free_presses := 3

@export_group("Attack")
@export var attack_kills_at_zero := true      # health reaching 0 kills the agent

var pilots: Array = []                        # slot -> Pilot, or null (free slot)
var _flights: Array[Dictionary] = []          # thrown items in the air: {sp, j, pos, vel}
var _legacy := {}                             # older species driven through player_index
var _last_delta := 0.0


## The PilotSystem of this AlifeManager (its child "Pilots"), created if missing.
static func ensure(am: AlifeManager) -> PilotSystem:
	var s := am.get_node_or_null("Pilots") as PilotSystem
	if s == null and am.has_meta("pilot_system"):
		s = am.get_meta("pilot_system")       # created this frame, not in the tree yet
	if s != null:
		return s
	s = PilotSystem.new()
	s.name = "Pilots"
	s.alifemanager = am
	am.set_meta("pilot_system", s)
	am.add_child.call_deferred(s)
	return s


func _ready() -> void:
	add_to_group("between_ticks")             # SimulationManager calls between_ticks()


## Solo, or the host: inputs are applied here. A client only sends its inputs.
func is_authority() -> bool:
	return multiplayer.is_server()


# --- Pilots ------------------------------------------------------------------------------

## Starts controlling agent i of species sp. Returns the Pilot, or null if that agent is
## already controlled (by anyone) or the species can't be controlled.
func add_pilot(sp, i: int, peer_id := 1) -> Pilot:
	if not ("pilot_id" in sp):
		push_error("PilotSystem: species %s has no pilot_id (update the ALIFE base script)" % sp.species_name)
		return null
	if i < 0 or i >= sp.entity_count or sp.active_alife_array[i] == 0:
		return null
	if sp.pilot_id[i] >= 0:
		return null                           # someone already plays it
	var slot := pilots.find(null)
	if slot < 0:
		slot = pilots.size()
		pilots.append(null)
	var pl := Pilot.new()
	pl.id = slot
	pl.peer_id = peer_id
	pl.species = sp
	pl.index = i
	var v: Vector3 = sp.current_velocity[i]
	v.y = 0.0
	pl.facing = v.normalized() if v.length_squared() > 1e-6 else Vector3.FORWARD
	pilots[slot] = pl
	sp.pilot_system = self
	sp.pilot_id[i] = slot
	pilot_added.emit(pl)
	return pl


## Stops controlling: drops what it carries, gives the agent back to its AI.
func remove_pilot(pl: Pilot) -> void:
	if pl == null or pl.id < 0 or pl.id >= pilots.size() or pilots[pl.id] != pl:
		return
	var sp = pl.species
	if pl.index < sp.pilot_id.size() and sp.pilot_id[pl.index] == pl.id:
		if sp.active_alife_array[pl.index] != 0:
			alifemanager.when_free(_drop.bind(pl))   # arrays may be busy (pipelined tick)
		sp.pilot_id[pl.index] = -1
	pilots[pl.id] = null
	pl.charging = false
	pl.eating = false
	pilot_removed.emit(pl)


## All pilots of one network peer (e.g. to remove them when it disconnects).
func pilots_of(peer_id: int) -> Array:
	return pilots.filter(func(p): return p != null and p.peer_id == peer_id)


## Network: an input packet for a pilot. One-shot presses not used yet are kept,
## so a press is never lost when two packets arrive in the same frame.
func receive_input(pilot_slot: int, bytes: PackedByteArray) -> void:
	if pilot_slot < 0 or pilot_slot >= pilots.size() or pilots[pilot_slot] == null:
		return
	var pl: Pilot = pilots[pilot_slot]
	var inp := PlayerInput.from_bytes(bytes)
	if inp.seq < pl.input.seq:
		return                                # older than what we have
	inp.pressed |= pl.input.pressed
	pl.input = inp


# --- Per frame ---------------------------------------------------------------------------

## Called by SimulationManager right before each tick (arrays free). delta = real time
## since the last call.
func between_ticks(delta: float) -> void:
	if alifemanager == null or not _world_ready():
		return
	_last_delta = delta
	for pl in pilots.duplicate():
		if pl == null:
			continue
		if not pl.is_valid():
			remove_pilot(pl)                  # died, removed, or slot reused
			continue
		if pl.poll.is_valid():
			var inp: PlayerInput = pl.poll.call()
			inp.pressed |= pl.input.pressed   # not consumed yet (e.g. authority off)
			pl.input = inp
		if is_authority():
			_apply(pl, delta)
	if is_authority():
		_process_flights(delta)
		for sp in alifemanager.species_array:
			if sp.has_method("update_talks"):
				sp.update_talks()             # NPC conversations: close when too far
	_sync_legacy()


## AlifeManager has done at least one update: global ids (species offsets) and the
## contact grid exist for every species (targets, attacks and find_nearest need them).
func _world_ready() -> bool:
	var am := alifemanager
	return am.species_array.size() > 0 \
			and am.global_species_offset.size() == am.species_array.size() + 1 \
			and am.cell_start.size() > 0


func _apply(pl: Pilot, delta: float) -> void:
	var sp = pl.species
	var i := pl.index
	var inp := pl.input
	var mask: int = sp.control_actions
	var held := inp.held & mask
	var pressed := inp.pressed & mask
	var raw_pressed := inp.pressed            # every button (struggling works for any species)
	inp.pressed = 0                           # consumed

	# Carried (or thrown) by someone: no actions. Jump presses struggle free.
	var state: int = sp.active_alife_array[i]
	if state != AlifeManager.ACTIVE:
		pl.charging = false
		_cancel_eat(pl)
		pl.target_species = null
		pl.target_index = -1
		pl.target_machine = null
		if state == AlifeManager.HELD:
			if raw_pressed & PlayerInput.JUMP != 0:
				pl.struggle += 1
			if break_free_presses > 0 and pl.struggle >= break_free_presses:
				_break_free(pl)
		return
	pl.struggle = 0

	# Timers (real time: they work while the simulation is paused too)
	pl.attack_cd = maxf(pl.attack_cd - delta, 0.0)
	pl.dash_cd = maxf(pl.dash_cd - delta, 0.0)
	pl.dash_left = maxf(pl.dash_left - delta, 0.0)
	pl.jump_buffer = maxf(pl.jump_buffer - delta, 0.0)

	# Facing: the keys being pressed (instant, even when paused), else the real movement
	var f := Vector3(inp.move.x, 0.0, inp.move.y)
	if f.length_squared() < 1e-6:
		f = sp.current_velocity[i]
		f.y = 0.0
	if f.length_squared() > 1e-6:
		pl.facing = f.normalized()
	if "facing" in sp:
		sp.facing[i] = pl.facing              # the carry system places the item with it

	_find_targets(pl)

	# Released: throw / stop eating
	if pl.charging and held & PlayerInput.THROW == 0:
		pl.charging = false
		_throw(pl)
	if pl.eating and held & PlayerInput.EAT == 0:
		_cancel_eat(pl)

	# One-shot actions. What each may do is decided BEFORE any of them runs, so one press
	# of a key bound to several actions doesn't chain (pick up then use what was picked up).
	if pressed != 0:
		var item := held_item(pl)
		var holding: bool = item[0] != null
		var can := {
			PlayerInput.JUMP: true,
			PlayerInput.DASH: true,
			PlayerInput.ATTACK: true,
			PlayerInput.ACTION: true,
			PlayerInput.USE: pl.target_machine != null or (holding and item[0].has_method("use")),
			PlayerInput.PICK_UP: not holding and pl.target_species != null,
			PlayerInput.THROW: holding,
			PlayerInput.DROP: holding,
			PlayerInput.EAT: holding and not (item[0].has_method("can_be_eaten") \
					and not item[0].can_be_eaten(item[1])),
		}
		for b in can:
			if pressed & b == 0 or not can[b]:
				continue
			if sp.on_control_action(pl, b):
				continue                      # the species did its own thing
			_default_action(pl, b, item)

	# Held: charge the throw, fill the eat circle
	if pl.charging:
		pl.charge = minf(pl.charge + delta / maxf(throw_charge_time, 0.01), 1.0)
	if pl.eating:
		var item := held_item(pl)
		if item[0] == null:
			_cancel_eat(pl)                   # dropped / thrown meanwhile
		else:
			pl.eat_progress += delta / maxf(eat_hold_time, 0.01)
			if pl.eat_progress >= 1.0:
				_cancel_eat(pl)
				_eat(pl, item[0], item[1])


func _default_action(pl: Pilot, b: int, item: Array) -> void:
	match b:
		PlayerInput.JUMP:
			pl.jump_buffer = jump_buffer_time
		PlayerInput.DASH:
			_dash(pl)
		PlayerInput.ATTACK:
			_attack(pl)
		PlayerInput.ACTION:
			var t := _interact_target(pl)
			_interact(pl, t[0], t[1])
		PlayerInput.USE:
			if pl.target_machine != null:
				_use_machine(pl)              # near a machine: feed it / start / stop
			else:
				item[0].use(item[1], pl.species, pl.index)
		PlayerInput.PICK_UP:
			_pick_up(pl, pl.target_species, pl.target_index)
		PlayerInput.THROW:
			pl.charging = true                # charge while held, throw on release
			pl.charge = 0.0
		PlayerInput.DROP:
			_drop(pl)
		PlayerInput.EAT:
			pl.eating = true                  # the circle fills while held
			pl.eat_progress = 0.0


## [species, local index] of what the pilot's agent carries, or [null, -1].
func held_item(pl: Pilot) -> Array:
	var id: int = pl.species.holding[pl.index]
	if id == -1:
		return [null, -1]
	return alifemanager.split_cid(id)         # carry ids, not global ids


# --- Targets -----------------------------------------------------------------------------

## Machine whose zone we're in, else the closest other agent (or hanging fruit) in range.
## Machines and agents are compared relative to their ranges, so a big zone doesn't steal
## the focus from something small right next to us. Nothing while carrying (hands full).
func _find_targets(pl: Pilot) -> void:
	var sp = pl.species
	var pos: Vector3 = sp.position_array[pl.index]
	var best_score := INF
	pl.target_machine = null
	for m in get_tree().get_nodes_in_group("machines"):
		var d := WorldWrap.nearest_image(m.global_position, pos).distance_to(pos)
		if d > m.interact_range:
			continue
		var score := d / maxf(m.interact_range, 0.001)
		if score < best_score:
			best_score = score
			pl.target_machine = m

	pl.target_species = null
	pl.target_index = -1
	if held_item(pl)[0] != null:
		return
	var me := alifemanager.g_id(sp, pl.index)
	var found: Vector4 = sp.find_nearest(pos, me, -1, target_search_rings)
	var id := int(found.w)
	var agent_dist := Vector3(found.x, found.y, found.z).length()
	var agent_score := agent_dist / maxf(target_range, 0.001)
	if id >= 0 and agent_dist <= target_range and agent_score < best_score:
		var t := alifemanager.split_id(id)
		pl.target_species = t[0]
		pl.target_index = t[1]
		pl.target_machine = null
		best_score = agent_score

	# Fruits hanging in trees aren't in the contact grid: asked to the species that have them
	for fsp in alifemanager.species_array:
		if not fsp.has_method("find_hanging_fruit"):
			continue
		var f: int = fsp.find_hanging_fruit(pos, target_range)
		if f < 0:
			continue
		var fruit_dist: float = WorldWrap.nearest_image(fsp.position_array[f], pos).distance_to(pos)
		var fruit_score := fruit_dist / maxf(target_range, 0.001)
		if fruit_score < best_score:
			best_score = fruit_score
			pl.target_species = fsp
			pl.target_index = f
			pl.target_machine = null


## Closest agent to interact with: an NPC always wins, else the closest agent in range.
func _interact_target(pl: Pilot) -> Array:
	var sp = pl.species
	var pos: Vector3 = sp.position_array[pl.index]
	var me := alifemanager.g_id(sp, pl.index)
	var best: Array = [null, -1]
	var best_d := target_range
	for isp in alifemanager.species_array:
		if not ("npc_data" in isp):
			continue
		var f: Vector4 = sp.find_nearest(pos, me, isp.species_id, target_search_rings)
		if int(f.w) >= 0:
			var fd := Vector3(f.x, f.y, f.z).length()
			if fd <= best_d:
				best_d = fd
				best = alifemanager.split_id(int(f.w))
	if best[0] != null:
		return best
	for isp in alifemanager.species_array:
		var found: Vector4 = sp.find_nearest(pos, me, isp.species_id, target_search_rings)
		var id := int(found.w)
		if id < 0:
			continue
		var d := Vector3(found.x, found.y, found.z).length()
		if d <= best_d:
			best_d = d
			best = alifemanager.split_id(id)
	return best


# --- Actions -----------------------------------------------------------------------------

func _dash(pl: Pilot) -> void:
	if pl.dash_cd > 0.0:
		return
	pl.dash_cd = pl.species.dash_cooldown
	pl.dash_left = pl.species.dash_time
	dashed.emit(pl)


func _interact(pl: Pilot, target_sp, j: int) -> void:
	if target_sp == null or not target_sp.has_method("Interact"):
		return
	print("%s #%d interacts with %s #%d" % [pl.species.species_name, pl.index, target_sp.species_name, j])
	target_sp.Interact(j, pl.species, pl.index)       # (target index, who, who's index)


## use: feed the machine in range what you carry, or start / stop it with empty hands.
func _use_machine(pl: Pilot) -> void:
	var item := held_item(pl)
	var m = pl.target_machine
	if m != null and m.has_method("interact"):
		var used: bool = m.interact(pl.species, pl.index, item[0], item[1])
		if used and item[0] != null:
			alifemanager.unlink(item[0], item[1])     # the carried item went into the machine


func _pick_up(pl: Pilot, item_sp, j: int) -> void:
	var sp = pl.species
	var i := pl.index
	if item_sp == null:
		return
	if not carry_players and "pilot_id" in item_sp and j < item_sp.pilot_id.size() \
			and item_sp.pilot_id[j] >= 0:
		return                                        # another player's agent
	if item_sp.has_method("harvest") and item_sp.harvest(j, sp, i):
		pl.target_species = null                      # ripe bush: the berry is now in hand
		pl.target_index = -1
		return
	if item_sp.has_method("can_be_carried") and not item_sp.can_be_carried(j):
		return                                        # e.g. a grown tree
	if item_sp.has_method("detach_fruit"):
		item_sp.detach_fruit(j)                       # a fruit grabbed from its branch
	if not alifemanager.pick_up(sp, i, item_sp, j):
		if sp.has_method("can_carry") and not sp.can_carry(i, item_sp, j):
			print("%s #%d: too big to carry (size %.1f needs power %d, has %d)" % [
					sp.species_name, i, item_sp.current_size[j],
					alifemanager.item_carry_class(item_sp, j), sp.carrying_power[i]])
		return                                        # hands full, too big, or item not free
	print("%s #%d picks up %s #%d" % [sp.species_name, i, item_sp.species_name, j])
	pl.target_species = null
	pl.target_index = -1
	picked_up.emit(pl, item_sp, j)


## A carried player struggled free: its carrier drops it in front of itself.
func _break_free(pl: Pilot) -> void:
	pl.struggle = 0
	var c: int = pl.species.held_by[pl.index]
	if c == -1:
		return
	var t := alifemanager.split_cid(c)
	var p := alifemanager.carry_position(t[0], t[1])
	p.y = t[0].position_array[t[1]].y
	alifemanager.drop(t[0], t[1], p)
	print("%s #%d broke free" % [pl.species.species_name, pl.index])


## Put the item down in front of the carrier, at its feet level.
func _drop(pl: Pilot) -> void:
	var item := held_item(pl)
	if item[0] == null:
		return
	var cs = pl.species
	var ci := pl.index
	var p := alifemanager.carry_position(cs, ci)
	p.y = cs.position_array[ci].y
	alifemanager.drop(cs, ci, p)
	dropped.emit(pl, item[0], item[1])


func _cancel_eat(pl: Pilot) -> void:
	pl.eating = false
	pl.eat_progress = 0.0


func _eat(pl: Pilot, food_sp, j: int) -> void:
	var sp = pl.species
	var i := pl.index
	print("%s #%d eats %s #%d" % [sp.species_name, i, food_sp.species_name, j])
	if food_sp.has_method("on_eaten"):
		food_sp.on_eaten(j, sp, i)                    # items: their own effect
	else:
		sp.current_energy_array[i] += food_sp.current_biomass[j]   # creatures / plants: biomass
	alifemanager.unlink(food_sp, j)                   # free the hands before the slot is reused
	food_sp.Remove_Life(j)
	ate.emit(pl, food_sp, j)


## Throw released: launch the carried item, power from how long it was held.
func _throw(pl: Pilot) -> void:
	if held_item(pl)[0] == null:
		return
	var cs = pl.species
	var ci := pl.index
	var dir := pl.aim_dir()
	var speed := lerpf(throw_min_speed, throw_max_speed, pl.charge)
	var a := deg_to_rad(throw_angle_deg)
	var vel := dir * cos(a) * speed + Vector3.UP * sin(a) * speed
	var pos := alifemanager.carry_position(cs, ci)
	# Out of the hands, but not back in the world yet: the simulation leaves it alone
	var item: Array = alifemanager.release_flying(cs, ci)
	if item.is_empty():
		return
	_flights.append({"sp": item[0], "j": item[1], "pos": pos, "vel": vel})
	thrown.emit(pl, item[0], item[1], speed)


## Every frame (real time, so it works while paused too): move items in the air.
func _process_flights(delta: float) -> void:
	for f in _flights.duplicate():
		var sp = f["sp"]
		var j: int = f["j"]
		if sp.active_alife_array[j] == 0:             # removed mid-air
			_flights.erase(f)
			continue
		var vel: Vector3 = f["vel"]
		var pos: Vector3 = f["pos"]
		vel.y -= throw_gravity * delta
		pos += vel * delta
		var landed := pos.y <= ground_y
		if landed:
			pos.y = ground_y
		# Stay in the world: wrap on wrapped axes, stop at the edge otherwise
		pos = WorldWrap.wrap_into(pos)
		var ws := WorldWrap.size
		if WorldWrap.mask.x == 0.0: pos.x = clampf(pos.x, 0.0, ws.x)
		if WorldWrap.mask.z == 0.0: pos.z = clampf(pos.z, 0.0, ws.z)
		f["vel"] = vel
		f["pos"] = pos
		sp.position_array[j] = pos
		if sp.has_method("mark_moved"):
			sp.mark_moved(j)                      # static species: its field cell changed
		if landed:
			_flights.erase(f)
			alifemanager.land(sp, j, pos)             # back in the world
			item_landed.emit(sp, j, pos)


## attack: hit every agent inside a box in front of the agent. Box size, damage and
## cooldown come from the attacker's species (attack_width, attack_length...).
func _attack(pl: Pilot) -> void:
	if pl.attack_cd > 0.0:
		return
	var sp = pl.species
	var i := pl.index
	pl.attack_cd = sp.attack_cooldown

	var origin: Vector3 = sp.position_array[i]
	var fwd := pl.aim_dir()
	var right := Vector3.UP.cross(fwd).normalized()
	pl.facing = fwd

	# Damage: the attacker's strength (else its species' attack_damage) + the weapon's bonus.
	# Area: the attack box, scaled by the carried weapon.
	var damage: float = sp.get_damage(i) if sp.has_method("get_damage") else sp.attack_damage
	var area := 1.0
	var weapon := held_item(pl)
	if weapon[0] != null and weapon[0].has_method("weapon_damage_bonus"):
		damage += weapon[0].weapon_damage_bonus(weapon[1])
		area = weapon[0].weapon_area_scale(weapon[1])
	var width: float = sp.attack_width * area
	var length: float = sp.attack_length * area
	var height: float = sp.attack_height

	pl.attack_serial += 1
	pl.attack_origin = origin
	pl.attack_basis = Basis(right * width, Vector3.UP * height, fwd * length)

	var hits := _agents_in_box(origin, right, fwd, sp, i, width, length, height)
	for h in hits:
		var hsp = h[0]
		var j: int = h[1]
		var before: float = hsp.current_health[j]
		var taken := damage
		if "damage_reduction" in hsp:
			taken = maxf(damage - hsp.damage_reduction, 0.0)   # armour: flat reduction
		var b: float = before - taken
		hsp.current_health[j] = maxf(b, 0.0)
		DamageEffects.hit(hsp, j, before - hsp.current_health[j])   # flash + number
		hsp.on_damaged(j, sp, i)
		if attack_kills_at_zero and b <= 0.0:
			hsp.alive_array[j] = 0                    # the simulation handles the corpse
	attacked.emit(pl, hits)


## Every living agent whose position is inside the box (wrap-aware), except the attacker.
func _agents_in_box(origin: Vector3, right: Vector3, fwd: Vector3, me_sp, me_i: int,
		width: float, length: float, height: float) -> Array:
	var am := alifemanager
	var hits: Array = []
	var W: int = am.GRID_W
	var H: int = am.GRID_H
	var D: int = am.GRID_D
	var cs: Vector3 = am.cell_size
	var cell_start: PackedInt32Array = am.cell_start
	var cell_items: PackedInt32Array = am.cell_items
	var sorted_pos: PackedVector3Array = am.sorted_pos
	var active: PackedInt32Array = am.global_active
	var me := am.g_id(me_sp, me_i)
	var wx := WorldWrap.mask.x > 0.0
	var wz := WorldWrap.mask.z > 0.0
	var ws := WorldWrap.size

	var center := origin + fwd * length * 0.5
	var reach := Vector2(width * 0.5, length * 0.5).length()
	var cx := clampi(int(fposmod(center.x, ws.x) / cs.x) if wx else int(center.x / cs.x), 0, W - 1)
	var cz := clampi(int(fposmod(center.z, ws.z) / cs.z) if wz else int(center.z / cs.z), 0, D - 1)
	var rx := ceili(reach / cs.x) + 1
	var rz := ceili(reach / cs.z) + 1
	if wx: rx = mini(rx, (W - 1) / 2)
	if wz: rz = mini(rz, (D - 1) / 2)

	var half_w := width * 0.5
	for zz in range(cz - rz, cz + rz + 1):
		var z := posmod(zz, D) if wz else zz
		if z < 0 or z >= D:
			continue
		for y in H:
			for xx in range(cx - rx, cx + rx + 1):
				var x := posmod(xx, W) if wx else xx
				if x < 0 or x >= W:
					continue
				var cell := x + W * (y + H * z)
				for k in range(cell_start[cell], cell_start[cell + 1]):
					var j: int = cell_items[k]
					if j == me or active[j] != AlifeManager.ACTIVE:
						continue
					var d: Vector3 = sorted_pos[k] - origin
					if wx: d.x -= ws.x * roundf(d.x / ws.x)
					if wz: d.z -= ws.z * roundf(d.z / ws.z)
					var along := d.dot(fwd)
					var across := d.dot(right)
					if along < 0.0 or along > length or absf(across) > half_w:
						continue
					if d.y < -0.5 or d.y > height:
						continue
					var t := am.split_id(j)
					if t[0].alive_array[t[1]] == 0:
						continue                      # corpses aren't hit
					hits.append(t)
	return hits


# --- Older species (uses_pilots = false) ---------------------------------------------------

## Species not updated yet still read player_index / player_velocity / player_jump_*:
## the first pilot of such a species drives them, so it stays controllable (one player).
func _sync_legacy() -> void:
	var seen := {}
	for pl in pilots:
		if pl == null or pl.species.uses_pilots or seen.has(pl.species):
			continue
		var sp = pl.species
		seen[sp] = true
		_legacy[sp] = true
		sp.player_index = pl.index
		var v: Vector3 = sp.control_velocity(pl, pl.index, sp.position_array[pl.index], 0.0, 0.0, false)
		sp.player_velocity = Vector3(v.x, 0.0, v.z)
		sp.player_jump_held = pl.input.is_held(PlayerInput.JUMP)
		if pl.jump_buffer > 0.0:
			sp.player_jump_buffer = pl.jump_buffer
			pl.jump_buffer = 0.0
		sp.player_jump_buffer = maxf(sp.player_jump_buffer - _last_delta, 0.0)
	for sp in _legacy.keys():
		if not seen.has(sp):
			sp.player_index = -1
			sp.player_velocity = Vector3.ZERO
			_legacy.erase(sp)
