@tool
extends Resource
class_name HeightGrid
## Where agents can walk, baked once into a grid (by NavWorld). Read-only afterwards,
## so species can read it from their worker threads, for any number of agents.
## A Resource: NavWorld can save it to a .res file in the editor (bake_now) and just
## load it at game start instead of building it again.
##
## Several floors per cell (bridges, caverns, floors above floors), highest first:
##   heights[(cx + w * cz) * layers + k] = height of floor k in that cell, k = 0 the highest
##   NAN = no more floors in that cell (a cell with only NAN is not walkable at all)
## An agent stands on the highest floor that is at most max_step_up above its feet.

var heights := PackedFloat32Array()
var layers := 1                     # floors stored per cell
var origin := Vector2.ZERO          # world x, z of the grid's corner
var cell := 0.5                     # cell size (world units)
var inv_cell := 2.0
var w := 0                          # cells along x
var d := 0                          # cells along z
var max_step_up := 0.5              # feet can go this much higher without jumping
## Agent body: from max_step_up above the feet to agent_height above them. It must not
## overlap any solid span (walls, floating boxes...), and the head stops under them.
var agent_height := 2.0
## The body starts this far above the feet: geometry lower than that is the floor / a step
## (slopes and bumps inside a cell). Small, so the body can't slip under thin objects.
var body_margin := 0.2
## Solid spans per cell, where real geometry is (from its bottom to its top), lowest first:
##   blocks[(cell * block_layers + k) * 2] = bottom, [+1] = top. NAN = no more spans.
## Empty: no geometry was read (only the navigation mesh floors are used).
var blocks := PackedFloat32Array()
var block_layers := 4
var player_only := false            # true: only the controlled agent is limited
## An agent standing where there is no floor (pushed, spawned or landed there) is put back
## on the nearest walkable cell within this many cells. Further away: it stays stuck.
var snap_radius := 8


## Settings the grid was built with (NavWorld checks them: a different value = rebake).
var bake_settings := {}


## Saved to the file (PROPERTY_USAGE_STORAGE) but not shown in the Inspector: the big
## arrays would make the editor slow when the resource is selected.
func _get_property_list() -> Array:
	var out := []
	for n in ["heights", "blocks"]:
		out.append({"name": n, "type": TYPE_PACKED_FLOAT32_ARRAY, "usage": PROPERTY_USAGE_STORAGE})
	for n in ["layers", "w", "d", "block_layers", "snap_radius"]:
		out.append({"name": n, "type": TYPE_INT, "usage": PROPERTY_USAGE_STORAGE})
	for n in ["cell", "inv_cell", "max_step_up", "agent_height", "body_margin"]:
		out.append({"name": n, "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_STORAGE})
	out.append({"name": "origin", "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_STORAGE})
	out.append({"name": "player_only", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_STORAGE})
	out.append({"name": "bake_settings", "type": TYPE_DICTIONARY, "usage": PROPERTY_USAGE_STORAGE})
	return out


## Cell index at (x, z), -1 outside the grid.
func _cell(x: float, z: float) -> int:
	var cx := int(floorf((x - origin.x) * inv_cell))
	var cz := int(floorf((z - origin.y) * inv_cell))
	if cx < 0 or cz < 0 or cx >= w or cz >= d:
		return -1
	return cx + w * cz


## Index of the first floor of the cell at (x, z), -1 outside the grid.
func _base(x: float, z: float) -> int:
	var c := _cell(x, z)
	return c * layers if c >= 0 else -1


## True if an agent with its feet at height `feet` at (x, z) would be inside solid
## geometry (between a step above the feet and its head).
## `ah`: this agent's body height (-1 = agent_height). Species of different sizes pass it.
func body_blocked(x: float, z: float, feet: float, ah: float = -1.0) -> bool:
	if blocks.is_empty():
		return false
	var c := _cell(x, z)
	if c < 0:
		return false
	var lo_body := feet + body_margin
	var hi_body := feet + (agent_height if ah <= 0.0 else ah) - 0.01   # touching isn't inside
	var o := c * block_layers * 2
	for k in block_layers:
		var lo := blocks[o + 2 * k]
		if is_nan(lo):
			return false                         # no more spans
		if lo >= hi_body:
			return false                         # lowest first: the rest is above the head
		if blocks[o + 2 * k + 1] > lo_body:
			return true
	return false


## The floor under feet at height y: the highest floor at most max_step_up above them.
## NAN: none (outside, a wall, or only floors too high to step onto).
func floor_at(x: float, z: float, y: float) -> float:
	var b := _base(x, z)
	if b < 0:
		return NAN
	var reach := y + max_step_up
	for k in layers:
		var h := heights[b + k]
		if is_nan(h):
			return NAN                          # no more floors (highest first)
		if h <= reach:
			return h
	return NAN


## Top of the solid geometry right under feet at height `feet` (at most max_step_up above
## them), -INF if none. Lets agents land and stand on solid tops that aren't floors (the
## steep edge of a hull, a thin wall's top) instead of going through them.
func solid_top_under(x: float, z: float, feet: float) -> float:
	if blocks.is_empty():
		return -INF
	var c := _cell(x, z)
	if c < 0:
		return -INF
	var best := -INF
	var reach := feet + max_step_up
	var o := c * block_layers * 2
	for k in block_layers:
		var lo := blocks[o + 2 * k]
		if is_nan(lo) or lo > reach:
			break                                # lowest first: the rest is higher
		var hi := blocks[o + 2 * k + 1]
		if hi <= reach:
			best = maxf(best, hi)
	return best


## Highest point the feet can reach at (x, z), for an agent whose feet are at `floor_h` (its
## floor, or where it is now if higher): the bottom of the lowest solid span (or floor)
## above its body, minus agent_height. INF when nothing is above. Only what is ABOVE the
## agent counts: something under it never pushes it down.
func ceiling_at(x: float, z: float, floor_h: float, ah: float = -1.0) -> float:
	var c := _cell(x, z)
	if c < 0:
		return INF
	# Same body as body_blocked: everything above floor_h + body_margin is over the body
	var start := floor_h + body_margin
	var above := INF
	var b := c * layers
	for k in layers:
		var h := heights[b + k]
		if is_nan(h) or h <= start:
			break                                # this floor and everything below
		above = h                                # floors are highest first: keeps the lowest one above
	if not blocks.is_empty():
		var o := c * block_layers * 2
		for k in block_layers:
			var lo := blocks[o + 2 * k]
			if is_nan(lo):
				break
			if blocks[o + 2 * k + 1] > start:    # reaches above the body's start
				above = minf(above, maxf(lo, start))   # real bottom of what's above (box, wall)
				break
	return above - (agent_height if ah <= 0.0 else ah) if above < INF else INF


## Solid spans of the cell at (x, z), lowest first: [bottom, top, bottom, top...] (debug).
func spans_at(x: float, z: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var c := _cell(x, z)
	if c < 0 or blocks.is_empty():
		return out
	var o := c * block_layers * 2
	for k in block_layers:
		if is_nan(blocks[o + 2 * k]):
			break
		out.append(blocks[o + 2 * k])
		out.append(blocks[o + 2 * k + 1])
	return out


## Highest floor of the cell (any height), NAN if none.
func height_at(x: float, z: float) -> float:
	var b := _base(x, z)
	return heights[b] if b >= 0 else NAN


func is_walkable(x: float, z: float) -> bool:
	return not is_nan(height_at(x, z))


## One move, from p (last tick) to q (wanted). Returns Vector3(x, floor, z): the accepted
## horizontal spot and the floor height there. Only local values: safe from many threads.
## Long moves (fast agents) are checked in steps of half a cell: nothing thin is skipped.
func move(p: Vector3, q: Vector3, fl: float, ah: float = -1.0) -> Vector3:
	var dx := q.x - p.x
	var dz := q.z - p.z
	var dist := sqrt(dx * dx + dz * dz)
	var n := ceili(dist / (cell * 0.5))
	if n <= 1 or n > 256:                         # short move, or a teleport / wrap jump
		return _move_step(p, q, fl, ah)
	dx /= n
	dz /= n
	var cur := p
	var f := fl
	for s in n:
		var target := Vector3(cur.x + dx, p.y, cur.z + dz)
		var r := _move_step(cur, target, f, ah)
		if r.x == cur.x and r.z == cur.z:
			return r                             # blocked: stop here
		if r.x == cur.x:
			dx = 0.0                             # slid along a wall: keep sliding
		if r.z == cur.z:
			dz = 0.0
		cur = Vector3(r.x, p.y, r.z)
		f = r.y
	return Vector3(cur.x, f, cur.z)


## One short move (at most about half a cell).
##   a floor at most a step above the feet: accepted
##   else: x move only, then z move only (slides along walls and edges), else stays
##   no floor at all where the agent stands: back to the nearest walkable cell
## Cells with no floor are never entered.
func _move_step(p: Vector3, q: Vector3, fl: float, ah: float = -1.0) -> Vector3:
	var h := _free_floor(q.x, q.z, p.y, ah)
	if not is_nan(h):
		return Vector3(q.x, h, q.z)
	var hx := _free_floor(q.x, p.z, p.y, ah)      # slide: keep the x move only
	if not is_nan(hx):
		return Vector3(q.x, hx, p.z)
	var hz := _free_floor(p.x, q.z, p.y, ah)      # slide: keep the z move only
	if not is_nan(hz):
		return Vector3(p.x, hz, q.z)
	var here := _free_floor(p.x, p.z, p.y, ah)
	if not is_nan(here):
		return Vector3(p.x, here, p.z)            # blocked: stay
	# Standing where there is no floor, or inside / under something too low (got in during
	# a jump): back onto the closest spot where the agent fits
	var back := nearest_walkable(p.x, p.z, p.y, ah)
	if not is_nan(back.y):
		return back
	return Vector3(p.x, fl, p.z)                  # nothing walkable nearby: stays


## Floor the feet (height y) can step onto at (x, z) without the body hitting anything.
## NAN: no such floor, or a wall / floating obstacle in the way.
func _free_floor(x: float, z: float, y: float, ah: float = -1.0) -> float:
	var h := floor_at(x, z, y)
	if is_nan(h) or body_blocked(x, z, maxf(y, h), ah):
		return NAN
	return h


## Center of the closest cell where the agent fits on a floor (feet at height y), searching
## rings of cells around (x, z) up to snap_radius. Vector3(x, floor, z), or y = NAN if none.
## First only on the same level (a floor within a step of the feet): pushed out of a wall
## from inside a room, it stays inside, instead of landing outside / on another level.
## Only if nothing is found there: any level.
func nearest_walkable(x: float, z: float, y: float, ah: float = -1.0) -> Vector3:
	var r := _nearest(x, z, y, true, ah)
	if is_nan(r.y):
		r = _nearest(x, z, y, false, ah)
	return r


func _nearest(x: float, z: float, y: float, same_level: bool, ah: float = -1.0) -> Vector3:
	var cx := int(floorf((x - origin.x) * inv_cell))
	var cz := int(floorf((z - origin.y) * inv_cell))
	for r in range(1, snap_radius + 1):
		var best := Vector3(0.0, NAN, 0.0)
		var best_d2 := INF
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue                     # only this ring
				var px := origin.x + (cx + dx + 0.5) * cell
				var pz := origin.y + (cz + dz + 0.5) * cell
				var h := _free_floor(px, pz, y, ah)
				if same_level:
					if is_nan(h) or absf(h - y) > max_step_up:
						continue                 # not on this level
				elif is_nan(h):
					var top := floor_at(px, pz, INF)     # none in step reach: the highest floor
					if not is_nan(top) and not body_blocked(px, pz, top, ah):
						h = top
				if is_nan(h):
					continue
				var d2 := (px - x) * (px - x) + (pz - z) * (pz - z)
				if d2 < best_d2:
					best_d2 = d2
					best = Vector3(px, h, pz)
		if not is_nan(best.y):
			return best                          # closest ring with a floor
	return Vector3(x, NAN, z)
