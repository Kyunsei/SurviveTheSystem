extends SubViewportContainer
## Pan / zoom a Camera2D inside this container's SubViewport (Godot 4).
## Input is only handled while the mouse is over this container.
##
## Mouse wheel: zoom toward the cursor | Right or middle drag: pan
## Arrow keys: pan (only while the mouse is over the map) | Home: reset view
##
## Scene setup:
##   SubViewportContainer   <- this script
##     SubViewport
##       Camera2D           <- assign to `camera` in the Inspector
##       MultiMeshInstance2D, map nodes, ...

@export var camera: Camera2D
@export var zoom_step := 1.25
@export var min_zoom := 0.1
@export var max_zoom := 64.0
@export var key_pan_speed := 600.0          # screen pixels per second
## The map area in world units, e.g. Rect2(0, 0, 4800, 4800) with (0, 0) at the top-left.
## The camera starts centered on it and can't leave it. Leave empty for no limit.
@export var world_rect := Rect2()
## Start zoomed so the whole map fits in the view (needs world_rect).
@export var fit_on_start := true

var _hovered := false
var _dragging := false
var _start_position := Vector2.ZERO
var _start_zoom := Vector2.ONE


func _ready() -> void:
	assert(camera != null, "Assign the Camera2D in the Inspector")
	stretch = true                           # SubViewport follows the container size
	mouse_filter = Control.MOUSE_FILTER_STOP
	camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	camera.position_smoothing_enabled = false

	mouse_entered.connect(func(): _hovered = true)
	mouse_exited.connect(func(): _hovered = false)

	# Wait one frame so the container (and SubViewport) has its final size
	_init_view.call_deferred()


func _init_view(worldsize:Vector3= Vector3.ZERO) -> void:
	world_rect = Rect2(0,0,worldsize.x,worldsize.z)
	if world_rect.has_area():
		camera.position = world_rect.get_center()
		if fit_on_start:
			var view := camera.get_viewport_rect().size
			var fit := minf(view.x / world_rect.size.x, view.y / world_rect.size.y)
			var z := clampf(fit, min_zoom, max_zoom)
			camera.zoom = Vector2(z, z)
	_start_position = camera.position
	_start_zoom = camera.zoom


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom_at(event.position, zoom_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_at(event.position, 1.0 / zoom_step)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_dragging = event.pressed
			_:
				return                       # let other buttons through (e.g. left click on agents)
		accept_event()

	elif event is InputEventMouseMotion and _dragging:
		# A drag keeps going even if the mouse leaves the container
		camera.position -= event.relative / stretch_shrink / camera.zoom
		_clamp_camera()
		accept_event()


func _process(delta: float) -> void:
	if not _hovered:
		return

	if Input.is_physical_key_pressed(KEY_HOME):
		camera.position = _start_position
		camera.zoom = _start_zoom
		return

	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_LEFT):  dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT): dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_UP):    dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_DOWN):  dir.y += 1.0
	if dir != Vector2.ZERO:
		# Same on-screen speed at any zoom level
		camera.position += dir.normalized() * key_pan_speed * delta / camera.zoom
		_clamp_camera()


## Zoom while keeping the world point under the cursor in place.
func _zoom_at(mouse_pos: Vector2, factor: float) -> void:
	var from_center := mouse_pos / stretch_shrink - camera.get_viewport_rect().size * 0.5
	var world_under_mouse := camera.position + from_center / camera.zoom

	var z := clampf(camera.zoom.x * factor, min_zoom, max_zoom)
	camera.zoom = Vector2(z, z)

	camera.position = world_under_mouse - from_center / camera.zoom
	_clamp_camera()


func _clamp_camera() -> void:
	if not world_rect.has_area():
		return
	camera.position = camera.position.clamp(world_rect.position, world_rect.end)
