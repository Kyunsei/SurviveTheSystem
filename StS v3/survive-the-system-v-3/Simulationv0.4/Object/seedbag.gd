extends ALIFE_ITEM
class_name ALIFE_SEEDBAG
## Example item: a bag of seeds. Use it while holding it to plant one at your feet.

var plant_species := "GLOWBERRY"     # species_name of what gets planted
var plant_spread := 0.5              # random offset around the feet


func _init() -> void:
	super()
	species_name = "SEEDBAG"
	sprite =preload("res://assets/Art from STS2/poop_star.png")   # TODO: your seed bag sprite
	colour = Color(0.75, 0.6, 0.35, 1.0)
	max_uses = 5
	consumed_when_empty = true
	use_cooldown = 0.5


func _on_use(_i: int, user_sp: ALIFE, user_i: int) -> bool:
	var sp: ALIFE = alifemanager.codex.species.get(plant_species)
	if sp == null:
		push_warning("SEEDBAG: no species named %s" % plant_species)
		return false
	var at: Vector3 = user_sp.position_array[user_i]
	at = sp.pick_random_position(Vector3(plant_spread, 0.0, plant_spread), at)
	at.y = user_sp.ground_y
	var before := sp.active_entity_count
	sp.Build_New_Life(at, sp.seed_energy)
	return sp.active_entity_count > before       # false if the world is full
