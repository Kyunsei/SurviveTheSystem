extends ALIFE
class_name ALIFE_POWER_FRUIT
## Power fruit: an item. Eat it and the eater's carrying power becomes `carrying_power_given`.
##
## Lies still in the world, never ages, never dies on its own, never reproduces.
## Pick it up, then hold the eat key (PlayerController calls on_eaten).
## Only works on species with a `carrying_power` array (e.g. CATRONAUTE).

@export var carrying_power_given := 50


func _init() -> void:
	species_name = "POWER_FRUIT"
	photosynthesis_on = false
	init_size = 1.0                  # carry class 1: any cat can pick it up
	sprite = preload("res://assets/assets kyun/mango1.png")   # <- your sprite here
	colour = Color(1.0, 0.75, 0.1, 1.0)
	seed_energy = 0.0
	seed_biomass = 10.0              # energy gained by eaters without carrying_power


## The eater (species sp, index i) eats fruit j.
func on_eaten(j: int, sp, i: int) -> void:
	if "carrying_power" in sp:
		sp.carrying_power[i] = maxi(sp.carrying_power[i], carrying_power_given)   # never lowers it
		print("%s #%d: carrying power is now %d" % [sp.species_name, i, sp.carrying_power[i]])
	else:
		sp.current_energy_array[i] += current_biomass[j]


func can_be_eaten(_j: int) -> bool:
	return true


## Items don't live: nothing to simulate (they only move when carried or thrown).
func run_chunk_simulation(start: int, end: int, local_id: int, delta: float, dt: float, sim_speed: float) -> void:
	spawn_per_chunk[local_id] = PackedInt32Array()
	remove_per_chunk[local_id] = PackedInt32Array()
