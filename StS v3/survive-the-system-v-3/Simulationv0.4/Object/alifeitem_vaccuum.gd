extends ALIFE_ITEM
class_name ALIFE_VACUUM
## Vacuum: a held item. Use (F) turns it on / off. While on, every suck_interval it
## sucks the agents in front of whoever holds it (a cone) into its tank: they leave
## the world and their biomass is stored. Each agent sucked costs durability;
## at 0 the vacuum breaks (removed). Turns off by itself when dropped or full.
##
## It can't be eaten (see can_be_eaten). Anyone holding it can use it: player or AI.

signal toggled(i: int, on: bool)                    # e.g. sounds / animations
signal sucked(i: int, sp: ALIFE, j: int)

#VACUUM (set in _init)
var suck_range := 2.0                # how far in front it reaches
var suck_angle_deg := 45.0           # half-angle of the cone
var suck_interval := 0.15            # seconds between two sucks
var max_per_suck := 3                # agents per suck
var capacity := 500                   # agents the tank holds (-1 = endless)
var max_durability := 100.0
var durability_per_suck := 0.33      # lost per agent sucked
var ignore_species: Array[String] = ["CATRONAUTE", "VACUUM"]   # never sucked
var suck_dead := true                # corpses too
var only_carriable := true           # respects the species' can_be_carried (no grown trees)
var debug_aoe := true               # draw the suck cone while held (green = on, grey = off)

# Per vacuum
var is_on := PackedByteArray()
var durability := PackedFloat32Array()
var stored_count := PackedInt32Array()
var stored_biomass := PackedFloat32Array()
var _last_suck := PackedFloat64Array()


func _init() -> void:
	super()
	species_name = "VACUUM"
	sprite = preload("res://assets/assets kyun/gold_vacuum1.png")   # TODO: your vacuum sprite
	colour = Color(0.55, 0.6, 0.7, 1.0)
	max_uses = -1                    # the on / off switch never runs out
	use_cooldown = 0.25

	#Held look: 3D model on the carrier's back instead of the sprite
	held_scene = preload("res://Simulationv0.4/Object/alifeitem_gold_vacuum.tscn")
	held_scene_scale = 1.0                         # size of the model
	held_on_body = true                            # from the carrier's body, not the hands
	held_scene_offset = Vector3(0.0, 0.3, 0.0)     # right, up, forward (-z = behind)
	held_scene_rotation = Vector3(0, 0, 0)         # x, y, z in degrees
	held_offset_with_size = true                   # offset grows with the carrier


func can_be_eaten(_i: int) -> bool:
	return false


## Use: switch on / off.
func _on_use(i: int, _user_sp: ALIFE, _user_i: int) -> bool:
	_ensure_vacuum_arrays()
	_set_on(i, is_on[i] == 0)
	return true


## Tank level for the bar above the held vacuum (HeldSceneManager).
func fill_ratio(i: int) -> float:
	_ensure_vacuum_arrays()
	if capacity < 0:
		return -1.0                              # endless tank: no bar
	return float(stored_count[i]) / maxf(capacity, 1.0)


func use_text(i: int) -> String:
	_ensure_vacuum_arrays()
	var tank := "%d" % stored_count[i] if capacity < 0 else "%d/%d" % [stored_count[i], capacity]
	return "%s · tank %s · %d%%" % ["ON" if is_on[i] else "off", tank,
			roundi(100.0 * durability[i] / maxf(max_durability, 0.001))]


func _set_on(i: int, on: bool) -> void:
	if (is_on[i] == 1) == on:
		return
	is_on[i] = 1 if on else 0
	print("VACUUM #%d %s  (tank %s)" % [i, "ON" if on else "OFF", _tank_text(i)])
	toggled.emit(i, on)


func Build_New_Life(pos: Vector3, e: float = seed_energy, lc := 0, col := Color(1, 1, 1, 1)):
	var i: int = free_indices[free_indices.size() - 1] if free_indices.size() > 0 else entity_count
	var before := active_entity_count
	super(pos, e, lc, col)
	if active_entity_count == before:
		return
	_ensure_vacuum_arrays()
	is_on[i] = 0
	durability[i] = max_durability
	stored_count[i] = 0
	stored_biomass[i] = 0.0
	_last_suck[i] = 0.0


## Called on the main thread once per tick (AlifeManager.update_alife): the safe place
## to remove other species' agents. The vacuums do their sucking here.
func Build_and_remove_pendings():
	super()
	_ensure_vacuum_arrays()
	var now := Time.get_ticks_msec() / 1000.0
	for i in entity_count:
		if is_on[i] == 0:
			continue
		if active_alife_array[i] == 0 or held_by[i] == -1:
			_set_on(i, false)                    # dropped / thrown / gone: switch off
			continue
		if now - _last_suck[i] < suck_interval:
			continue
		_last_suck[i] = now
		_suck(i)


## Where the cone starts and where it points: [origin, forward], or [] if it can't suck.
## Same for the sucking and the debug drawing.
func _cone(i: int) -> Array:
	if held_by[i] == -1:
		return []
	var holder := alifemanager.split_cid(held_by[i])
	var hsp: ALIFE = holder[0]
	var hi: int = holder[1]
	var origin: Vector3 = alifemanager.carry_position(hsp, hi)
	var fwd: Vector3 = origin - hsp.position_array[hi]
	fwd.y = 0.0
	if fwd.length_squared() < 1e-6:
		return []
	return [origin, fwd.normalized()]


## Debug drawing of the suck area (HeldSceneManager), or {} when off.
func aoe_shape(i: int) -> Dictionary:
	if not debug_aoe:
		return {}
	_ensure_vacuum_arrays()
	var c := _cone(i)
	if c.is_empty():
		return {}
	return {"origin": c[0], "forward": c[1], "range": suck_range,
			"angle_deg": suck_angle_deg, "active": is_on[i] == 1}


func _suck(i: int) -> void:
	var c := _cone(i)
	if c.is_empty():
		return
	var holder := alifemanager.split_cid(held_by[i])
	var hsp: ALIFE = holder[0]
	var hi: int = holder[1]
	var origin: Vector3 = c[0]
	var fwd: Vector3 = c[1]
	var cos_a := cos(deg_to_rad(suck_angle_deg))
	var r2 := suck_range * suck_range
	var ws: Vector3 = world.size
	var wx: bool = world.border_type_x == world.Border.WRAP
	var wz: bool = world.border_type_z == world.Border.WRAP

	var taken := 0
	for sp_any in alifemanager.species_array:
		var sp = sp_any                          # untyped: species-specific methods (can_be_carried)
		if sp == self or sp.species_name in ignore_species:
			continue
		var check_carry: bool = only_carriable and sp.has_method("can_be_carried")
		for j in sp.entity_count:
			if sp.active_alife_array[j] != 1:
				continue                         # pool, held, hanging, flying...
			if sp == hsp and j == hi:
				continue                         # not the holder
			if sp.alive_array[j] == 0 and not suck_dead:
				continue
			var d: Vector3 = sp.position_array[j] - origin
			if wx: d.x -= ws.x * roundf(d.x / ws.x)
			if wz: d.z -= ws.z * roundf(d.z / ws.z)
			var d2 := d.length_squared()
			if d2 > r2:
				continue
			if d2 > 1e-6 and Vector3(d.x, 0.0, d.z).normalized().dot(fwd) < cos_a:
				continue                         # outside the cone
			if check_carry and not sp.can_be_carried(j):
				continue
			if capacity >= 0 and stored_count[i] >= capacity:
				print("VACUUM #%d tank full (%s): switching off" % [i, _tank_text(i)])
				_set_on(i, false)                # tank full
				return

			# In the tank
			stored_count[i] += 1
			stored_biomass[i] += maxf(sp.current_biomass[j], 0.0)
			print("VACUUM #%d sucked %s #%d  ->  tank %s%s" % [i, sp.species_name, j, _tank_text(i),
					"  FULL" if capacity >= 0 and stored_count[i] >= capacity else ""])
			sucked.emit(i, sp, j)
			alifemanager.unlink(sp, j)
			sp.Remove_Life(j)
			durability[i] -= durability_per_suck
			if durability[i] <= 0.0:
				_break(i)
				return
			taken += 1
			if taken >= max_per_suck:
				return


## "12/50 (24%)", or "12" with an endless tank.
func _tank_text(i: int) -> String:
	if capacity < 0:
		return "%d" % stored_count[i]
	return "%d/%d (%d%%)" % [stored_count[i], capacity,
			roundi(100.0 * stored_count[i] / maxf(capacity, 1.0))]


## Out of durability: gone.
func _break(i: int) -> void:
	print("VACUUM #%d broke (durability 0)" % i)
	_set_on(i, false)
	alifemanager.unlink(self, i)
	Remove_Life(i)


## Empties the tank: returns the stored biomass (e.g. to feed a machine) and resets it.
func empty_tank(i: int) -> float:
	_ensure_vacuum_arrays()
	var b := stored_biomass[i]
	stored_count[i] = 0
	stored_biomass[i] = 0.0
	return b


func _ensure_vacuum_arrays() -> void:
	var old := is_on.size()
	if old >= entity_count:
		return
	is_on.resize(entity_count)
	durability.resize(entity_count)
	stored_count.resize(entity_count)
	stored_biomass.resize(entity_count)
	_last_suck.resize(entity_count)
	for k in range(old, entity_count):
		is_on[k] = 0
		durability[k] = max_durability
		stored_count[k] = 0
		stored_biomass[k] = 0.0
		_last_suck[k] = 0.0
