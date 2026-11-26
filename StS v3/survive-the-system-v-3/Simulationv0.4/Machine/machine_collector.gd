class_name Collector
extends Machine
## Biomass collector (mission machine), on the new carry / machine system.
##
## Near it (ring on the ground), with the use key:
##   carrying a vacuum: its tank is emptied into the collector (you keep the vacuum)
##   carrying an agent (grass, berry, sheep...): it's consumed, its biomass collected
##   carrying another item (ALIFE_ITEM, e.g. a seed bag): refused
## Collected = biomass x factor.
## Thresholds are STAGES stacked on top of each other: with [50, 200, 1000, 2000] the
## rewards come at 50, 250, 1250 and 3250 collected. The last one is the mission goal
## (max_biomass = their sum, computed), and the fill of InsideMesh is measured against it.
## Each stage reached pays its credits into the shop bank (Shop.credits). The last stage
## completes the mission: it can speed the simulation up for a while (time warp), then a
## bigger mission starts (every stage x next_max_mult).
##
## Scene: same children as before (all optional):
##   sign/signlabel            Label3D  "Next reward at ..."
##   collected_amount_Label3D  Label3D  "Biomass collected x / max"
##   InsideMesh                MeshInstance3D  fills up with the biomass

signal threshold_reached(index: int, reward: int)
signal mission_completed(max_biomass: float)

@export var factor := 0.01                     # collected = biomass x factor
@export var thresholds: Array[float] = [50.0, 200.0, 1000.0, 2000.0]   # stage sizes, stacked
@export var rewards: Array[int] = [20, 30, 40, 50]   # credits per stage (same order)
@export var final_reward := 60                 # extra, on top of the last stage's reward
@export_group("After the mission")
@export var next_max_mult := 1.5               # next mission: every stage x this
@export var sim_manager: SimulationManager     # optional: time warp after the mission
@export var warp_speed := 600.0
@export var warp_seconds := 5.0                # real seconds of warp (0 = no warp)
@export_group("Inside mesh")
@export var inside_init_height := 3.8
@export var inside_offset := -3.7

var biomass_collected := 0.0
var max_biomass := 0.0                         # goal: sum of the stages (computed)
var collecting := true
var _next := 0                                 # next threshold index

@onready var _sign: Label3D = get_node_or_null("sign/signlabel")
@onready var _amount: Label3D = get_node_or_null("collected_amount_Label3D")
@onready var _inside: MeshInstance3D = get_node_or_null("InsideMesh")


func _ready() -> void:
	if machine_name == "Machine":
		machine_name = "Collector"
	super()
	_label.visible = false                     # the scene has its own labels
	_compute_goal()
	_update_texts()


## Where each stage ends (stacked), and the goal = the last one.
func _stage_end(k: int) -> float:
	var total := 0.0
	for n in mini(k + 1, thresholds.size()):
		total += thresholds[n]
	return total


func _compute_goal() -> void:
	max_biomass = _stage_end(thresholds.size() - 1)


# --- Machine overrides -------------------------------------------------------------

func interact(_agent_species, _agent_index: int, held_species, held_index: int) -> bool:
	if not collecting:
		print("COLLECTOR: full, waiting for the next mission")
		return false
	if held_species == null:
		return false                           # nothing to give (no start / stop)

	# Vacuum: empty its tank, keep the vacuum
	if held_species.has_method("empty_tank"):
		_collect(held_species.empty_tank(held_index), "vacuum tank")
		return false

	# Other items (tools) aren't biomass
	if held_species is ALIFE_ITEM:
		print("COLLECTOR: you try to give an item")
		return false

	# An agent: consumed
	var b: float = maxf(held_species.current_biomass[held_index], 0.0)
	held_species.alifemanager.unlink(held_species, held_index)
	held_species.Remove_Life(held_index)
	_collect(b, held_species.species_name)
	return true


func start() -> void:
	pass                                       # never "runs"


func status_text() -> String:
	return "%s   ·   %d / %d biomass   ·   use: give" % [
			machine_name, roundi(biomass_collected), roundi(max_biomass)]


# --- Collecting ----------------------------------------------------------------------

func _collect(biomass: float, what: String) -> void:
	var gained := biomass * factor
	biomass_collected += gained
	print("COLLECTOR: +%.2f from %s  ->  %d / %d" % [gained, what,
			roundi(biomass_collected), roundi(max_biomass)])
	_check_thresholds()
	_update_texts()


func _check_thresholds() -> void:
	while _next < thresholds.size() and biomass_collected >= _stage_end(_next):
		var reward: int = rewards[_next] if _next < rewards.size() else 0
		_pay(reward)
		threshold_reached.emit(_next, reward)
		_next += 1
	if collecting and _next >= thresholds.size():
		collecting = false
		_pay(final_reward)
		print("COLLECTOR: mission complete!")
		mission_completed.emit(max_biomass)
		_after_mission()


func _pay(credits: int) -> void:
	if credits <= 0:
		return
	Shop.credits += credits
	print("COLLECTOR: +%d credits  ->  %d" % [credits, roundi(Shop.credits)])


## Mission done: optional time warp, then a bigger mission.
func _after_mission() -> void:
	_update_texts()
	if sim_manager != null and warp_seconds > 0.0:
		var old :float= sim_manager.simulation_speed
		sim_manager.simulation_speed = warp_speed
		await get_tree().create_timer(warp_seconds).timeout
		sim_manager.simulation_speed = old
	biomass_collected = 0.0
	for k in thresholds.size():
		thresholds[k] *= next_max_mult           # every stage bigger
	_compute_goal()
	_next = 0
	collecting = true
	_update_texts()


# --- Visuals --------------------------------------------------------------------------

func _update_texts() -> void:
	if _amount:
		if not collecting:
			_amount.text = "%d biomass reached, congratulations!!!" % roundi(max_biomass)
		else:
			_amount.text = "Biomass collected %d / %d" % [roundi(biomass_collected), roundi(max_biomass)]
	if _sign:
		if not collecting:
			_sign.text = "You completed your mission!"
		else:
			_sign.text = "Next reward at %d Biomass" % roundi(_stage_end(_next))
	if _inside:
		var fill := clampf(biomass_collected / maxf(max_biomass, 0.001), 0.0, 1.0)
		_inside.scale.y = maxf(fill, 0.001)        # never 0: a zero scale breaks the mesh
		var natural := inside_offset + inside_init_height * fill
		var y := (natural + inside_init_height * fill) / 2.0
		_inside.position.y = y
		_base_pos[_inside] = _inside.position      # keep it when the machine follows the view


func _update_label() -> void:
	pass                                       # base label hidden: texts above instead
