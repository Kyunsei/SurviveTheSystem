extends ALIFE
class_name ALIFE_ITEM
## Base class for objects that do something when USED while held (use key, F).
## Items are normal agents (so they can lie on the ground, be picked up, carried,
## thrown, dropped), but they don't live: no energy, no growth, no death, no AI.
##
## Make your own item: extend this class and override _on_use():
##
##   extends ALIFE_ITEM
##   class_name ALIFE_TORCH
##   func _init() -> void:
##       super()
##       species_name = "TORCH"
##       sprite = preload("res://.../torch.png")
##       max_uses = -1                          # never runs out
##   func _on_use(i, user_sp, user_i) -> bool:
##       print("light!")
##       return true                            # true = it was used (cooldown, one use spent)
##
## Anyone holding it can use it, player or AI:
##   item_sp.use(item_index, user_species, user_index)
## The PlayerController calls it on the use key for whatever the agent carries.

#ITEM (set in _init)
var max_uses := -1                   # uses per item (-1 = unlimited)
var consumed_when_empty := true      # removed from the world after its last use
var use_cooldown := 0.3              # seconds between two uses of the same item

#HELD LOOK (set in _init): a 3D scene shown in the hands instead of the sprite
# (needs a HeldSceneManager node in the scene)
var held_scene: PackedScene = null
var held_scene_scale := 1.0
var held_scene_rotation := Vector3.ZERO # degrees, fixes a model facing the wrong way:
										# (0, 180, 0) turned around, (0, 90, 0) quarter turn
var held_scene_offset := Vector3.ZERO   # local to the carrier: x right, y up, z forward
var held_on_body := false               # false: from the hands (in front); true: from the
										# carrier's feet, e.g. a backpack: offset (0, 1, -0.3)
var held_offset_with_size := true       # offset x the carrier's size (follows its growth)
var hide_sprite_when_held := true

var uses_left := PackedInt32Array()  # per item
var _next_use_time := PackedFloat64Array()


func _init() -> void:
	species_name = "ITEM"
	photosynthesis_on = false
	interactable = false
	max_life_cycle = 0
	growth_cost = [0]
	growth_rate = 0.0
	max_speed = 0.0
	init_size = 1.0
	seed_energy = 1.0
	seed_biomass = 1.0


## Items don't live: nothing to simulate. (Override if an item should do something
## on its own, e.g. a lamp running out.)
func run_chunk_simulation(start: int, end: int, local_id: int, delta:float,dt: float, sim_speed: float) -> void:
	spawn_per_chunk[local_id] = PackedInt32Array()
	remove_per_chunk[local_id] = PackedInt32Array()


## Every item can be picked up.
func can_be_carried(_i: int) -> bool:
	return true


#EATING (set in _init): tools aren't food, food items set edible = true
var edible := true

func can_be_eaten(_i: int) -> bool:
	return edible


## Item i is eaten by agent eater_i of species eater_sp. Override for special effects.
## Default: the eater gains the item's biomass as energy. The caller removes the item.
func on_eaten(i: int, eater_sp: ALIFE, eater_i: int) -> void:
	eater_sp.current_energy_array[eater_i] += maxf(current_biomass[i], 0.0)


## Uses item i, held by agent user_i of species user_sp. Returns true if it was used.
## Checks: it must be held by that agent, off cooldown, with uses left.
func use(i: int, user_sp: ALIFE, user_i: int) -> bool:
	_ensure_item_arrays()
	if held_by[i] != alifemanager.cid(user_sp, user_i):
		return false                             # only the one holding it
	var now := Time.get_ticks_msec() / 1000.0
	if now < _next_use_time[i]:
		return false                             # cooling down
	if uses_left[i] == 0:
		return false                             # empty (kept when consumed_when_empty is off)

	if not _on_use(i, user_sp, user_i):
		return false                             # nothing happened (e.g. no target)

	_next_use_time[i] = now + use_cooldown
	if uses_left[i] > 0:
		uses_left[i] -= 1
		if uses_left[i] == 0 and consumed_when_empty:
			alifemanager.unlink(self, i)         # out of the hands first
			Remove_Life(i)
	return true


## What the item does. Override it. Return true if it did something.
func _on_use(i: int, user_sp: ALIFE, user_i: int) -> bool:
	print("%s #%d used %s #%d" % [user_sp.species_name, user_i, species_name, i])
	return true


## How full the item is, 0..1, for the bar above it while held (< 0 = no bar).
func fill_ratio(_i: int) -> float:
	return -1.0


## Text for the status line, e.g. "3 uses left".
func use_text(i: int) -> String:
	_ensure_item_arrays()
	return "" if uses_left[i] < 0 else "%d uses left" % uses_left[i]


## New items get a full set of uses (slots are reused: reset at birth).
func Build_New_Life(pos: Vector3, e: float = seed_energy, lc := 0, col := Color(1, 1, 1, 1)):
	var i: int = free_indices[free_indices.size() - 1] if free_indices.size() > 0 else entity_count
	var before := active_entity_count
	super(pos, e, lc, col)
	if active_entity_count == before:
		return
	_ensure_item_arrays()
	uses_left[i] = max_uses
	_next_use_time[i] = 0.0


func _ensure_item_arrays() -> void:
	var old := uses_left.size()
	if old < entity_count:
		uses_left.resize(entity_count)
		_next_use_time.resize(entity_count)
		for k in range(old, entity_count):
			uses_left[k] = max_uses
			_next_use_time[k] = 0.0


## Same as every species, but a held item with a held_scene isn't drawn as a sprite
## (its 3D scene is shown instead by the HeldSceneManager).
func write_rendering_buffer_in_chunk(start: int, end: int) -> void:
	super(start, end)
	if held_scene == null or not hide_sprite_when_held:
		return
	var r_data := rend_data.data
	for i in range(start, end):
		if active_alife_array[i] == AlifeManager.HELD:
			r_data[i * 4 + 3] = 0.0              # state FREE for the shader: not drawn
