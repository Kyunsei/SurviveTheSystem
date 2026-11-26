extends ALIFE
class_name ALIFE_WEAPON
## Weapon: an item. While it is carried, its carrier's attacks hit harder and wider.
##
## PlayerController._attack asks the carried item for weapon_damage_bonus(j) and
## weapon_area_scale(j). Not edible. Lies still in the world, never dies on its own.

@export var damage_bonus := 30.0     # added to the carrier's strength
@export var area_scale := 2.0        # attack box width and length multiplied by this


func _init() -> void:
	species_name = "CLAWS"
	photosynthesis_on = false
	init_size = 1.0                  # carry class 1: any cat can pick it up
	sprite =preload("res://assets/Art from STS2/crab_claw.png")        # <- your sprite here
	colour = Color(0.75, 0.75, 0.8, 1.0)
	seed_energy = 0.0
	seed_biomass = 0.0


## Extra damage while weapon j is carried.
func weapon_damage_bonus(_j: int) -> float:
	return damage_bonus


## Attack box size multiplier while weapon j is carried.
func weapon_area_scale(_j: int) -> float:
	return area_scale


func can_be_eaten(_j: int) -> bool:
	return false


## Items don't live: nothing to simulate (they only move when carried or thrown).
func run_chunk_simulation(start: int, end: int, local_id: int, delta: float, dt: float, sim_speed: float) -> void:
	spawn_per_chunk[local_id] = PackedInt32Array()
	remove_per_chunk[local_id] = PackedInt32Array()
