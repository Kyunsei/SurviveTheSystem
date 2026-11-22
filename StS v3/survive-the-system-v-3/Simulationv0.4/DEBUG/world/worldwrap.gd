class_name WorldWrap
## Wrap-around helpers shared by the camera, picking, spawning and UI.
## Call once at startup, after the world exists:
##   WorldWrap.configure(world.size, wrap_x, wrap_y, wrap_z)
##
## The world goes from 0 to `size` on each axis. On wrapped axes, a position and
## the same position +/- size are the same place.
##
## Two levels:
##   mask      : which axes wrap in the world's LOGIC (always on, used e.g. for spawning)
##   view_mask : which axes wrap on SCREEN. Only when `visual` is on (control modes 1 and 2),
##               otherwise zero: the world is drawn with its normal edges.

static var size := Vector3(100.0, 100.0, 100.0)
static var mask := Vector3.ZERO      # 1.0 on wrapped axes, 0.0 otherwise
static var visual := false           # wrap-around display on / off (set by the controller)
## Little-planet look: the world is drawn bent down with distance (0 = flat).
## Same value as the `planet_radius` shader global (set by the controller).
static var planet_radius := 0.0


static func configure(world_size: Vector3, wrap_x: bool, wrap_y: bool, wrap_z: bool) -> void:
	size = world_size
	mask = Vector3(float(wrap_x), float(wrap_y), float(wrap_z))


static func is_enabled() -> bool:
	return mask != Vector3.ZERO


## Axes that wrap on screen right now (zero when the visual wrap is off).
static func view_mask() -> Vector3:
	return mask if visual else Vector3.ZERO


static func view_enabled() -> bool:
	return visual and is_enabled()


## The position brought back inside the world (0..size) on wrapped axes (logic).
static func wrap_into(p: Vector3) -> Vector3:
	if mask.x > 0.0: p.x = fposmod(p.x, size.x)
	if mask.y > 0.0: p.y = fposmod(p.y, size.y)
	if mask.z > 0.0: p.z = fposmod(p.z, size.z)
	return p


## Where `p` is DRAWN on the little planet around `center` (same formula as the shaders).
## The flat world is wrapped onto a sphere of radius planet_radius that touches the
## ground (y = 0) at `center`; heights above the ground stay heights.
## Use it for anything placed on screen from GDScript (picking, bars, arrows...).
static func curve(p: Vector3, center: Vector3) -> Vector3:
	if planet_radius <= 0.0:
		return p
	var dx := p.x - center.x
	var dz := p.z - center.z
	var dist := sqrt(dx * dx + dz * dz)
	if dist < 1e-5:
		return p
	var a := dist / planet_radius
	var r := planet_radius + p.y
	var s := sin(a) * r / dist
	return Vector3(center.x + dx * s, cos(a) * r - planet_radius, center.z + dz * s)


## Visible radius on the planet: a circle of half the world (not a square), and never past
## the far side of the ball. 0 = no limit (flat world).
static func planet_view_limit() -> float:
	if planet_radius <= 0.0:
		return 0.0
	return minf(minf(size.x, size.z) * 0.5, PI * planet_radius * 0.97)


## The copy of `p` the camera shows near `ref` (shortest way through the borders).
## Returns `p` unchanged while the visual wrap is off.
static func nearest_image(p: Vector3, ref: Vector3) -> Vector3:
	var m := view_mask()
	var d := p - ref
	if m.x > 0.0: d.x -= size.x * roundf(d.x / size.x)
	if m.y > 0.0: d.y -= size.y * roundf(d.y / size.y)
	if m.z > 0.0: d.z -= size.z * roundf(d.z / size.z)
	return ref + d
