extends ALIFE_ITEM
class_name ALIFE_CAT_RATION
## Energy ration: an item you eat (hold eat) to get energy and health back.
## Can be bought in the shop: add "ENERGY" to its catalog.

var energy_gain := 100.0              # energy given when eaten
var health_gain := 100.0              # health given when eaten
var cap_to_max := true               # not above the eater's max_energy / max health


func _init() -> void:
	super()
	species_name = "CAT_RATION"
	sprite = preload("res://objects/cat_ration/catration1.png")
	colour = Color(1.0, 0.8, 0.2, 1.0)
	edible = true


func on_eaten(_i: int, eater_sp: ALIFE, eater_i: int) -> void:
	var e: float = eater_sp.current_energy_array[eater_i] + energy_gain
	var h: float = eater_sp.current_health[eater_i] + health_gain
	if cap_to_max:
		e = minf(e, eater_sp.max_energy)
		h = minf(h, eater_sp.current_max_health[eater_i])
	var got_e: float = e - eater_sp.current_energy_array[eater_i]
	var got_h: float = h - eater_sp.current_health[eater_i]
	eater_sp.current_energy_array[eater_i] = e
	eater_sp.current_health[eater_i] = h
	print("%s #%d ate ENERGY: +%.0f energy, +%.0f health" % [eater_sp.species_name, eater_i, got_e, got_h])
