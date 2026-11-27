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

@export var factor := 0.001                     # collected = biomass x factor
@export var thresholds: Array[float] = [50.0, 200.0, 1000.0, 2000.0]   # stage sizes, stacked
@export var rewards: Array[int] = [20, 30, 40, 50]   # credits per stage (same order)
@export var final_reward := 60                 # extra, on top of the last stage's reward
@export_group("After the mission")
@export var next_max_mult := 1.5               # next mission: every stage x this
@export var sim_manager: SimulationManager     # optional: time warp after the mission
@export var warp_speed := 600.0
@export var warp_seconds := 5.0                # real seconds of warp (0 = no warp)
@export_group("Win screen")
@export var show_win_screen := true            # false: next mission starts on its own
@export var win_title := "Mission complete!"
@export_group("Inside mesh")
@export var inside_init_height := 3.8
@export var inside_offset := -3.7

var biomass_collected := 0.0
var max_biomass := 0.0                         # goal: sum of the stages (computed)
var collecting := true
var _next := 0                                 # next threshold index
var mission := 1                               # mission number (1, 2, 3...)
var _credits_this_mission := 0                 # shown on the win screen

signal win_screen_closed
var _win_layer: CanvasLayer = null

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
	_credits_this_mission += credits
	Shop.credits += credits
	print("COLLECTOR: +%d credits  ->  %d" % [credits, roundi(Shop.credits)])


## Mission done: optional time warp, then a bigger mission.
func _after_mission() -> void:
	_update_texts()                              # tank full
	if show_win_screen:
		show_win()
		await win_screen_closed                  # waits for Continue
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
	mission += 1
	_credits_this_mission = 0
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
		# Mesh centered on its origin (Box / Cylinder): bottom stays at inside_offset,
		# top rises to inside_offset + inside_init_height when full
		_inside.position.y = inside_offset + inside_init_height * fill * 0.5
		_base_pos[_inside] = _inside.position      # keep it when the machine follows the view


func _update_label() -> void:
	pass                                       # base label hidden: texts above instead


# --- Win screen ----------------------------------------------------------------------

## Shows the win screen (mission number, biomass, credits). Continue closes it and
## emits win_screen_closed. Built in code: no scene needed.
func show_win() -> void:
	if _win_layer != null:
		return                                     # already shown
	_win_layer = CanvasLayer.new()
	_win_layer.layer = 100                         # above the HUD
	_win_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_win_layer)

	# Dark background over the whole screen (also blocks clicks to the game)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_win_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_win_layer.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	style.border_color = Color(1.0, 0.85, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = win_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	box.add_child(title)

	var stats := Label.new()
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 18)
	stats.text = "Mission %d\nBiomass collected: %d\nCredits earned: +%d   (total %d)\n\nNext mission: %d biomass" % [
			mission, roundi(max_biomass), _credits_this_mission, roundi(Shop.credits),
			roundi(max_biomass * next_max_mult)]
	box.add_child(stats)

	var button := Button.new()
	button.text = "Continue"
	button.custom_minimum_size = Vector2(160, 40)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(close_win)
	box.add_child(button)

	# The cursor may be captured (camera / first person views): give it back
	_win_prev_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	button.grab_focus.call_deferred()             # Enter / Space also continues


var _win_prev_mouse := Input.MOUSE_MODE_VISIBLE


## Closes the win screen (Continue button, or call it from code).
func close_win() -> void:
	if _win_layer == null:
		return
	_win_layer.queue_free()
	_win_layer = null
	Input.mouse_mode = _win_prev_mouse
	win_screen_closed.emit()
