class_name Shop
extends Machine
## Shop: a machine whose currency is BIOMASS.
##
## Near the shop (ring on the ground), with the use key:
##   carrying a vacuum (or anything with empty_tank): its tank is emptied into credits
##   carrying any other agent:                        sold, its biomass becomes credits
##   empty hands:                                     opens the shop menu (click to buy)
## A bought item appears straight in your hands (or next to you if they're full).
##
## Credits are shared by every shop (one bank), see Shop.credits.
## Make a scene: a Node3D with this script and a mesh child, like any machine.
## Set the catalog in the inspector: species_name -> price, e.g. {"VACUUM": 50, "SEEDBAG": 10}

signal credits_changed(credits: float)
signal bought(species_name: String, price: int)

static var credits := 0.0                     # the bank, shared by every shop

@export var catalog := {"VACUUM": 50, "SEEDBAG": 10}
@export var credits_per_biomass := 1.0        # credits for one unit of biomass
@export var close_distance_margin := 0.5      # menu closes when you walk out of range

var _menu := CanvasLayer.new()
var _panel := PanelContainer.new()
var _credits_label := Label.new()
var _list := VBoxContainer.new()
var _customer_sp = null                       # who has the menu open
var _customer_i := -1


func _ready() -> void:
	machine_name = machine_name if machine_name != "Machine" else "Shop"
	super()
	_build_menu()


# --- Machine overrides -------------------------------------------------------------

## use key near the shop.
func interact(agent_species, agent_index: int, held_species, held_index: int) -> bool:
	# A vacuum: empty its tank into credits, keep the vacuum
	if held_species != null and held_species.has_method("empty_tank"):
		var b: float = held_species.empty_tank(held_index)
		_add_credits(b * credits_per_biomass, "vacuum tank (%.1f biomass)" % b)
		return false

	# Anything else carried: sell it
	if held_species != null:
		var b: float = maxf(held_species.current_biomass[held_index], 0.0)
		held_species.alifemanager.unlink(held_species, held_index)   # out of the hands first
		held_species.Remove_Life(held_index)
		_add_credits(b * credits_per_biomass, "%s (%.1f biomass)" % [held_species.species_name, b])
		return true

	# Empty hands: open / close the menu
	if _menu.visible:
		close_menu()
	else:
		open_menu(agent_species, agent_index)
	return false


func start() -> void:
	pass                                      # a shop never "runs": no energy used


func status_text() -> String:
	return "%s   ·   %d credits   ·   use: sell / open shop" % [machine_name, roundi(credits)]


func _update_label() -> void:
	_label.text = "%s\n%d credits" % [machine_name, roundi(credits)]
	_label.modulate = Color(1.0, 0.85, 0.3)


func _process(delta: float) -> void:
	super(delta)
	_update_label()                           # credits can change from any shop
	if _menu.visible:
		_refresh_menu()
		# Walked away, died, or released the agent: close
		var gone: bool = _customer_sp == null or _customer_sp.active_alife_array[_customer_i] == 0 \
				or _customer_sp.player_index != _customer_i
		if not gone:
			var p: Vector3 = _customer_sp.position_array[_customer_i]
			gone = WorldWrap.nearest_image(global_position, p).distance_to(p) \
					> interact_range + close_distance_margin
		if gone:
			close_menu()


# --- Credits / buying ----------------------------------------------------------------

func _add_credits(amount: float, what: String) -> void:
	credits += amount
	print("SHOP: +%.1f credits for %s  ->  %d credits" % [amount, what, roundi(credits)])
	credits_changed.emit(credits)
	_update_label()


## Buys one `sname` for the customer. Returns true if it worked.
func buy(sname: String) -> bool:
	if not catalog.has(sname) or _customer_sp == null:
		return false
	var price: int = catalog[sname]
	if credits < price:
		print("SHOP: not enough credits for %s (%d / %d)" % [sname, roundi(credits), price])
		return false
	var am: AlifeManager = _customer_sp.alifemanager
	var isp = am.codex.species.get(sname)
	if isp == null:
		push_warning("Shop: no species named %s" % sname)
		return false

	# New item next to the customer (Build_New_Life doesn't return the index: next free slot)
	var p: Vector3 = _customer_sp.position_array[_customer_i]
	var j: int = isp.free_indices[isp.free_indices.size() - 1] if isp.free_indices.size() > 0 \
			else isp.entity_count
	var before: int = isp.active_entity_count
	isp.Build_New_Life(am.keep_in_world(p + Vector3(0.5, 0.0, 0.5)), isp.seed_energy)
	if isp.active_entity_count == before:
		print("SHOP: the world is full, can't make %s" % sname)
		return false

	credits -= price
	credits_changed.emit(credits)
	bought.emit(sname, price)
	am.pick_up(_customer_sp, _customer_i, isp, j)   # straight into the hands (if they're free)
	print("SHOP: bought %s for %d  ->  %d credits left" % [sname, price, roundi(credits)])
	_update_label()
	close_menu()
	return true


# --- Menu (built by script) --------------------------------------------------------------

func open_menu(sp, i: int) -> void:
	_customer_sp = sp
	_customer_i = i
	_rebuild_list()
	_menu.visible = true


func close_menu() -> void:
	_menu.visible = false
	_customer_sp = null
	_customer_i = -1


func _build_menu() -> void:
	_menu.layer = 95
	_menu.visible = false
	add_child(_menu)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.05, 0.9)
	style.border_color = Color(1.0, 0.85, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	_menu.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)

	var title := Label.new()
	title.text = machine_name
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	col.add_child(title)

	_credits_label.add_theme_font_size_override("font_size", 14)
	col.add_child(_credits_label)

	col.add_child(_list)

	var close := Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_NONE        # keys keep moving the agent
	close.pressed.connect(close_menu)
	col.add_child(close)


func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	for sname in catalog:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(200, 30)
		b.set_meta("species", sname)
		b.pressed.connect(buy.bind(sname))
		_list.add_child(b)
	_refresh_menu()


## Prices and greyed-out buttons follow the credits.
func _refresh_menu() -> void:
	_credits_label.text = "Credits: %d   (1 biomass = %s)" % [roundi(credits), str(credits_per_biomass)]
	for b in _list.get_children():
		if not b.has_meta("species"):
			continue
		var sname: String = b.get_meta("species")
		var price: int = catalog[sname]
		b.text = "%s   —   %d" % [sname.capitalize(), price]
		b.disabled = credits < price
