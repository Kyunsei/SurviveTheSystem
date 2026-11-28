@tool
extends Node3D
class_name NavWorld
## Where agents can walk, from your 3D scene's meshes. Two things, built from the same source:
##
##   1. NAVIGATION MESH (NavigationRegion3D): for AI later. Paths around walls
##      (find_path), random reachable points (random_point). Main thread, a few calls.
##   2. HEIGHT GRID (HeightGrid): built once FROM the navigation mesh's polygons. Walls,
##      edges and several floors per cell (bridges, caverns). Read by the species in their
##      own tick, on the worker threads: fine for 100k agents.
##
## In the editor: tick `editor_preview` to see the grid as dots (every floor, low blue to
## high orange). Tick `refresh_preview` after rebaking the navigation mesh or changing
## the grid settings (it also refreshes on its own after a bake).
##
## Setup:
##   - NavigationRegion3D with a NavigationMesh. Its geometry: your scene meshes (as its
##     children, or a group: Geometry > Source Geometry Mode = Groups With Children).
##     Bake it in the editor (Bake NavigationMesh), or tick bake_navmesh_on_start.
##     Agent radius: SMALL (0 - 0.1). Agent height: below the gap under bridges / caves.
##   - This node: assign alifemanager and navigation_region.
##   - Species that use it: in species_names, and with a `height_grid` variable.

signal built(grid: HeightGrid)

@export var alifemanager: AlifeManager
@export var navigation_region: NavigationRegion3D:
	set(v):
		_disconnect_region()
		navigation_region = v
		_connect_region()
		_refresh_editor()
## Rebake the navigation mesh from the scene meshes when the game starts
## (else: the one baked in the editor is used; an empty one is baked anyway).
@export var bake_navmesh_on_start := false
## Species limited by it (species_name). Empty = EVERY species (default).
## Species with a `height_grid` variable (cat, cattle, NPC) handle it themselves (gravity,
## jumps, head room); every other one is limited by AlifeManager after each tick
## (walls block, agents stand on the floor where they end up).
@export var species_names: PackedStringArray = []
## Never limited (e.g. flying species). Also: species with `moves = false` (plants).
@export var exclude_species: PackedStringArray = []
## true: only the agent the player controls is limited (AI agents roam freely).
@export var only_controlled := false
## Off: agents are free again (flat ground, no walls). Can be switched while playing.
@export var enabled := true

@export_group("Height grid")
## Cell size (world units). Smaller = more precise edges, more memory, longer build.
@export var grid_cell := 0.5:
	set(v):
		grid_cell = maxf(v, 0.05)
		_refresh_editor()
## Feet can go up this much without jumping (steps, slopes). Higher surfaces are walls.
@export var max_step_up := 0.5
## Floors stored per cell (bridges, caverns, floors above floors). 1 = ground only.
@export_range(1, 8) var max_layers := 4:
	set(v):
		max_layers = v
		_refresh_editor()
## Navigation mesh floors sit up to its Cells > Height above the real surface: each floor
## is moved down onto the geometry surface just below it, if one is within this distance
## (agents stand exactly on the surface instead of floating). 0 = off.
@export var snap_to_geometry := 0.4:
	set(v):
		snap_to_geometry = v
		_refresh_editor()
## Two surfaces closer than this in the same cell count as one floor.
@export var min_layer_gap := 1.0:
	set(v):
		min_layer_gap = v
		_refresh_editor()
## The agent's height: its body (from a step above the feet to its head) must not overlap
## solid geometry, and its head stops under what's above (boxes, bridges, cave ceilings).
@export var agent_height := 2.0
## Solid spans stored per cell (walls, floating boxes stacked above each other).
@export_range(1, 16) var max_block_layers := 8
## An agent standing where it doesn't fit (no floor, or under something too low) is put
## back on the nearest spot where it fits, within this distance (world units).
@export var snap_radius := 4.0
## Also read the scene's real geometry (the same meshes / colliders the navigation mesh
## is baked from). Where the navigation mesh has no floor but there IS geometry (a wall, a
## thin pillar, a narrow top), the top of that geometry becomes the floor: too high to walk
## into, but you can jump onto it and over it. Where there is no geometry at all: void,
## never crossed. Off: every place without a navigation mesh floor is void.
@export var walls_from_geometry := true:
	set(v):
		walls_from_geometry = v
		_refresh_editor()
## A cell is walkable only if all 4 of its quarters are: thin walls and pillars always
## block (no cell center slipping past them). Paths get up to half a cell narrower.
@export var solid_edges := true:
	set(v):
		solid_edges = v
		_refresh_editor()

@export_group("Baked grid")
## Use the grid saved in the editor (fast start). Off: build it at every start (slow).
@export var use_baked := true
## The saved grid (filled by bake_now). Rebake after changing the level or the
## Height grid settings: a warning says so when the settings differ.
@export var baked_grid: HeightGrid
## Where bake_now saves it (.res = compact binary).
@export_file("*.res") var grid_file := "res://navworld_grid.res"
## Editor: tick to build the grid now and save it to grid_file (unticks itself).
## Takes as long as the old start did, once.
@export var bake_now := false:
	set(v):
		bake_now = false
		if v and Engine.is_editor_hint() and is_inside_tree():
			_bake_to_file()

@export_group("Debug")
## Editor: show the grid as dots.
@export var editor_preview := false:
	set(v):
		editor_preview = v
		_refresh_editor()
## Editor: tick to rebuild the preview now (unticks itself).
@export var refresh_preview := false:
	set(v):
		refresh_preview = false
		if v:
			_refresh_editor()
## In game: show the dots, and print a report on the controlled agent every second.
@export var show_debug := false

var grid: HeightGrid = null
var is_built := false
var _debug := MeshInstance3D.new()
var _warned := {}                             # species already warned about (once each)
var _report_timer := 0.0


func _ready() -> void:
	add_child(_debug, false, Node.INTERNAL_MODE_FRONT)
	_connect_region()
	if Engine.is_editor_hint():
		_refresh_editor()
		return
	build()


## (Re)builds everything in game: navigation mesh if needed, then the height grid.
## Call it again after changing the scene's meshes.
func build() -> void:
	is_built = false
	if navigation_region == null or navigation_region.navigation_mesh == null:
		push_error("NavWorld: assign a NavigationRegion3D with a NavigationMesh")
		return

	# 1. Navigation mesh (for paths; the grid is built from its polygons directly)
	var nm := navigation_region.navigation_mesh
	if bake_navmesh_on_start or nm.get_polygon_count() == 0:
		navigation_region.bake_navigation_mesh(true)     # on a thread
		await navigation_region.bake_finished
		if navigation_region.navigation_mesh.get_polygon_count() == 0:
			push_error("NavWorld: the bake found nothing walkable (check the geometry source)")
			return

	# 2. Height grid: the saved one (fast), else built now (slow)
	if use_baked and baked_grid != null and baked_grid.w > 0:
		grid = baked_grid
		_apply_runtime_settings(grid)
		var stale := _stale_settings(grid)
		if not stale.is_empty():
			push_warning("NavWorld: the baked grid was made with other settings (%s): tick bake_now in the editor" % ", ".join(stale))
	else:
		if use_baked:
			push_warning("NavWorld: no baked grid yet, building it now (slow). Tick bake_now in the editor to save it.")
		grid = _build_grid()

	# Species may not exist yet if this runs very early: wait for them
	while alifemanager != null and alifemanager.species_array.is_empty():
		await get_tree().process_frame
	is_built = true
	_assign()
	_draw(show_debug)
	built.emit(grid)


# --- For AI (main thread) ----------------------------------------------------------------

## Path from -> to around the walls (points along the navigation mesh). Empty if unreachable.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if not is_built:
		return PackedVector3Array()
	return NavigationServer3D.map_get_path(navigation_region.get_navigation_map(), from, to, true)


## A random walkable point (Godot 4.3+).
func random_point() -> Vector3:
	return NavigationServer3D.map_get_random_point(navigation_region.get_navigation_map(), 1, false)


## Closest walkable point to p.
func closest_point(p: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(navigation_region.get_navigation_map(), p)


# --- Quick checks (any thread, through the grid) -----------------------------------------

## Floor under feet at height y (several floors: bridges, caves).
func floor_at(x: float, z: float, y: float) -> float:
	return grid.floor_at(x, z, y) if grid != null else NAN


func is_walkable(x: float, z: float) -> bool:
	return grid != null and grid.is_walkable(x, z)


# --- Every frame (game) -------------------------------------------------------------------

## Gives the grid to the species again: cheap (one assignment per species), and survives
## species being created again or something else resetting it.
func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_built:
		return
	_assign()
	if show_debug:
		_report_timer -= delta
		if _report_timer <= 0.0:
			_report_timer = 1.0
			_report()


func _assign() -> void:
	if not is_built or alifemanager == null:
		return
	var walkers := {}
	for sp in alifemanager.species_array:
		var listed: bool = species_names.is_empty() or sp.species_name in species_names
		listed = listed and not (sp.species_name in exclude_species)
		if "height_grid" in sp:
			sp.height_grid = grid if (enabled and listed) else null   # does it itself
		elif listed and not ("moves" in sp and not sp.moves):
			walkers[sp] = true                     # the generic pass in AlifeManager
	alifemanager.walk_species = walkers
	alifemanager.walk_grid = grid if enabled else null


## show_debug: once per second, what the controlled agent sees.
func _report() -> void:
	var lines := PackedStringArray()
	lines.append("--- NavWorld report ---")
	lines.append("grid %d x %d x %d floors, cell %.2f, x %.1f..%.1f  z %.1f..%.1f" % [
			grid.w, grid.d, grid.layers, grid.cell,
			grid.origin.x, grid.origin.x + grid.w * grid.cell,
			grid.origin.y, grid.origin.y + grid.d * grid.cell])
	var found := false
	for sp in alifemanager.species_array:
		if not species_names.is_empty() and not (sp.species_name in species_names):
			continue
		var how := "not limited"
		if "height_grid" in sp:
			how = "itself (gravity, jumps, head room)" if sp.height_grid == grid else "not limited (no grid given)"
		elif alifemanager.walk_species.has(sp):
			how = "generic pass (walls, floors)"
		lines.append("%s: %s" % [sp.species_name, how])
		if "player_index" in sp and sp.player_index >= 0:
			found = true
			var i: int = sp.player_index
			var p: Vector3 = sp.position_array[i]
			var f := grid.floor_at(p.x, p.z, p.y)
			lines.append("  controlled #%d at (%.1f, %.2f, %.1f): floor under feet %s, ceiling %s" % [
					i, p.x, p.y, p.z, str(f), str(grid.ceiling_at(p.x, p.z, f))])
			# The cell just ahead (where the cat looks / moves): is it blocked, and by what?
			var dir := Vector3.ZERO
			if "facing" in sp and i < sp.facing.size():
				dir = sp.facing[i]
			if dir.length_squared() < 1e-6:
				dir = sp.current_velocity[i]
			dir.y = 0.0
			if dir.length_squared() > 1e-6:
				var a := p + dir.normalized() * grid.cell * 1.5
				var fa := grid.floor_at(a.x, a.z, p.y)
				var feet := maxf(p.y, fa) if not is_nan(fa) else p.y
				var why := "free"
				if is_nan(fa):
					why = "NO FLOOR within a step (wall, void, or step too high)"
				elif grid.body_blocked(a.x, a.z, feet):
					why = "BODY BLOCKED: a span overlaps %.2f..%.2f" % [
							feet + grid.body_margin, feet + grid.agent_height]
				lines.append("  ahead (%.1f, %.1f): floor %s, spans %s -> %s" % [
						a.x, a.z, str(fa), str(grid.spans_at(a.x, a.z)), why])
			var mm = sp.renderer3D.multimesh if sp.renderer3D != null else null
			if mm != null and mm.mesh is QuadMesh:
				var hgt: float = (mm.mesh as QuadMesh).size.y * sp.current_size[i]
				lines.append("  sprite height %.2f   agent_height %.2f%s" % [hgt, agent_height,
						"   <- agent_height is taller than the sprite" if agent_height > hgt * 1.1 else ""])
	if not found:
		lines.append("(no agent controlled)")
	print("\n".join(lines))


# --- Height grid, from the navigation mesh's polygons ---------------------------------------
# Pure geometry (no navigation server): works the same in the editor and in game.
# Every polygon is split into triangles; every cell center inside a triangle (seen from
# above) gets that triangle's height there. Several surfaces over the same cell are
# several floors: sorted highest first, merged when closer than min_layer_gap.

func _build_grid() -> HeightGrid:
	var g := HeightGrid.new()
	g.cell = maxf(grid_cell, 0.05)
	g.inv_cell = 1.0 / g.cell
	g.max_step_up = max_step_up
	g.player_only = only_controlled
	g.layers = maxi(max_layers, 1)
	g.agent_height = agent_height
	g.block_layers = maxi(max_block_layers, 1)
	g.snap_radius = maxi(ceili(snap_radius / g.cell), 1)
	g.body_margin = clampf(g.cell, 0.1, max_step_up)

	var nm := navigation_region.navigation_mesh if navigation_region != null else null
	if nm == null or nm.get_polygon_count() == 0:
		return g

	# Vertices in world space, and the bounds
	var xf := navigation_region.global_transform
	var verts := PackedVector3Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for v in nm.get_vertices():
		var c := xf * v
		verts.append(c)
		lo = Vector2(minf(lo.x, c.x), minf(lo.y, c.z))
		hi = Vector2(maxf(hi.x, c.x), maxf(hi.y, c.z))
	g.origin = lo
	g.w = maxi(ceili((hi.x - lo.x) * g.inv_cell), 1)
	g.d = maxi(ceili((hi.y - lo.y) * g.inv_cell), 1)

	# Every surface height over each sample point (sparse). solid_edges: 2 x 2 samples
	# per cell (its quarters), else 1 (its center).
	var sub := 2 if solid_edges else 1
	var fw := g.w * sub
	var fd := g.d * sub
	var fcell := g.cell / sub
	var found := {}                                # sample index -> PackedFloat32Array
	for pi in nm.get_polygon_count():
		var poly := nm.get_polygon(pi)
		for t in range(1, poly.size() - 1):        # triangle fan
			_raster_triangle(g.origin, fcell, fw, fd,
					verts[poly[0]], verts[poly[t]], verts[poly[t + 1]], found)

	# Real geometry over each sample point, as solid spans (bottom, top): a flat surface is
	# a span of no height, a wall seen edge-on spans from its bottom to its top
	var spans := {}                                # sample index -> PackedFloat32Array (lo, hi...)
	var walk_pts := {}                             # sample index -> heights of walkable surfaces
	# Walkable = no steeper than the navigation mesh's own Agents > Max Slope
	var max_tan := tan(deg_to_rad(clampf(nm.agent_max_slope, 0.0, 89.0)))
	if walls_from_geometry:
		var tris := _geometry_triangles()
		for t in range(0, tris.size(), 3):
			_raster_spans(g.origin, fcell, fw, fd, tris[t], tris[t + 1], tris[t + 2],
					spans, walk_pts, max_tan)
	# Floors found in the geometry, per sample: walkable surfaces (not steep) with room for
	# the agent above them (ground under a slab, cave floor, roof top). Used where the
	# navigation mesh has no floor. Steep walls are solid, never floors: no climbing them.
	var geo_floors := {}                           # sample index -> PackedFloat32Array
	for fi in walk_pts:
		var gf := _geometry_floors(walk_pts[fi], spans.get(fi, PackedFloat32Array()))
		if not gf.is_empty():
			geo_floors[fi] = gf
	if not spans.is_empty():
		g.blocks.resize(g.w * g.d * g.block_layers * 2)
		g.blocks.fill(NAN)

	# Per cell, from its samples (quarters with solid_edges). Each sample is:
	#   floors: navigation mesh floors (snapped onto the geometry), else walkable geometry
	#   solid only: geometry but no floor (a steep / thin wall): adds no floor, blocks
	#     through its spans
	#   void: nothing at all: the whole cell is void (never entered)
	# Geometry read: the cell's floors are all its samples' floors (a cell with none is a
	# wall). Navigation mesh only: the floors every sample agrees on, else the highest.
	g.heights.resize(g.w * g.d * g.layers)
	g.heights.fill(NAN)
	var tol := maxf(max_step_up, 0.05)
	var walkable := 0
	var multi := 0
	var walls := 0
	for cz in g.d:
		for cx in g.w:
			if not spans.is_empty():
				_store_blocks(g, cx + g.w * cz, cx, cz, sub, fw, spans)
			var b := (cx + g.w * cz) * g.layers
			var lists: Array[PackedFloat32Array] = []
			var all := PackedFloat32Array()
			var is_void := false
			for sz in sub:
				for sx in sub:
					var fi := (cx * sub + sx) + fw * (cz * sub + sz)
					if found.has(fi):
						var nav: PackedFloat32Array = found[fi]
						if snap_to_geometry > 0.0 and spans.has(fi):
							var snapped := PackedFloat32Array()
							for h in nav:
								snapped.append(_snap_down(h, spans[fi]))
							nav = snapped
						lists.append(_floors(nav))
						all.append_array(nav)
					elif geo_floors.has(fi):
						all.append_array(geo_floors[fi])
					elif not spans.has(fi):
						is_void = true             # nothing at all under this sample
				if is_void:
					break
			if is_void:
				continue
			var n := 0
			if not spans.is_empty():
				for h in _floors(all):             # every floor of any sample
					g.heights[b + n] = h
					n += 1
					if n >= g.layers:
						break
				if n == 0:
					walls += 1                     # only steep / thin geometry: a wall
					continue
			else:
				# Navigation mesh only: the floors every sample agrees on
				for h in lists[0]:
					var ok := true
					for k in range(1, lists.size()):
						if not _has_near(lists[k], h, tol):
							ok = false
							break
					if ok:
						g.heights[b + n] = h
						n += 1
						if n >= g.layers:
							break
				if n == 0:
					var highest := -INF            # samples disagree (an edge): the highest
					for fl in lists:
						highest = maxf(highest, fl[0])
					g.heights[b] = highest
					n = 1
					walls += 1
			walkable += 1
			if n > 1:
				multi += 1

	print("NavWorld: height grid %d x %d x %d floors: %d cells with a floor, %d with several, %d walls / edges" % [
			g.w, g.d, g.layers, walkable, multi, walls])
	return g


## Surface heights of one sample point -> its floors: highest first, merged when
## closer than min_layer_gap.
func _floors(hs: PackedFloat32Array) -> PackedFloat32Array:
	hs.sort()
	hs.reverse()
	var out := PackedFloat32Array()
	var last := INF
	for h in hs:
		if last - h >= min_layer_gap:
			out.append(h)
			last = h
	return out


func _has_near(list: PackedFloat32Array, h: float, tol: float) -> bool:
	for v in list:
		if absf(v - h) <= tol:
			return true
	return false


## Adds the triangle's height to every sample point inside it (seen from above).
## Samples: centers of a grid of `fcell` cells, fw x fd, starting at `origin`.
func _raster_triangle(origin: Vector2, fcell: float, fw: int, fd: int,
		a: Vector3, b: Vector3, c: Vector3, found: Dictionary) -> void:
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var c2 := Vector2(c.x, c.z)
	var den := (b2.y - c2.y) * (a2.x - c2.x) + (c2.x - b2.x) * (a2.y - c2.y)
	if absf(den) < 1e-9:
		return                                     # vertical / degenerate: not a floor
	var inv := 1.0 / fcell
	var x0 := maxi(int(floorf((minf(a2.x, minf(b2.x, c2.x)) - origin.x) * inv)), 0)
	var x1 := mini(int(floorf((maxf(a2.x, maxf(b2.x, c2.x)) - origin.x) * inv)), fw - 1)
	var z0 := maxi(int(floorf((minf(a2.y, minf(b2.y, c2.y)) - origin.y) * inv)), 0)
	var z1 := mini(int(floorf((maxf(a2.y, maxf(b2.y, c2.y)) - origin.y) * inv)), fd - 1)
	const EPS := -1e-4                             # include centers right on an edge
	for cz in range(z0, z1 + 1):
		var pz := origin.y + (cz + 0.5) * fcell
		for cx in range(x0, x1 + 1):
			var px := origin.x + (cx + 0.5) * fcell
			# Barycentric coordinates of the cell center
			var l1 := ((b2.y - c2.y) * (px - c2.x) + (c2.x - b2.x) * (pz - c2.y)) / den
			var l2 := ((c2.y - a2.y) * (px - c2.x) + (a2.x - c2.x) * (pz - c2.y)) / den
			var l3 := 1.0 - l1 - l2
			if l1 < EPS or l2 < EPS or l3 < EPS:
				continue
			var h := l1 * a.y + l2 * b.y + l3 * c.y
			var idx := cx + fw * cz
			if found.has(idx):
				var arr: PackedFloat32Array = found[idx]
				arr.append(h)
				found[idx] = arr                   # packed arrays are copies: store back
			else:
				found[idx] = PackedFloat32Array([h])


## The scene geometry the navigation mesh is baked from (same source settings: groups,
## meshes / colliders), as world-space triangles: 3 points per triangle.
func _geometry_triangles() -> PackedVector3Array:
	var out := PackedVector3Array()
	var nm := navigation_region.navigation_mesh
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, navigation_region)
	var v := src.get_vertices()                    # x, y, z, x, y, z... (region space)
	var idx := src.get_indices()
	var xf := navigation_region.global_transform
	out.resize(idx.size())
	for k in idx.size():
		var o := idx[k] * 3
		out[k] = xf * Vector3(v[o], v[o + 1], v[o + 2])
	return out


## Adds the triangle to the solid spans of every sample it covers (seen from above):
## its height there (a flat span). Steep or vertical triangles (walls seen edge-on) are
## traced along their footprint line, as a span from their bottom to their top.
func _raster_spans(origin: Vector2, fcell: float, fw: int, fd: int,
		a: Vector3, b: Vector3, c: Vector3, spans: Dictionary,
		walk_pts: Dictionary, max_tan: float) -> void:
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var c2 := Vector2(c.x, c.z)
	var inv := 1.0 / fcell
	var den := (b2.y - c2.y) * (a2.x - c2.x) + (c2.x - b2.x) * (a2.y - c2.y)
	# Width of its footprint seen from above (2 x area / longest side): a wall that is
	# vertical, or only slightly tilted, is a strip narrower than one sample
	var longest := sqrt(maxf(a2.distance_squared_to(b2),
			maxf(b2.distance_squared_to(c2), c2.distance_squared_to(a2))))
	var width := absf(den) / maxf(longest, 1e-6)
	if width < fcell:
		# Thin from above (a wall seen edge-on): walk along its footprint line, and at each
		# point take only the heights the triangle really covers THERE (the vertical cut
		# through it). A wall with a door: above the opening only the part above the door
		# is solid, not the whole wall height.
		var p0 := a2
		var p1 := b2
		if b2.distance_squared_to(c2) > p0.distance_squared_to(p1):
			p0 = b2
			p1 = c2
		if c2.distance_squared_to(a2) > p0.distance_squared_to(p1):
			p0 = c2
			p1 = a2
		var dir := p1 - p0
		var len2 := dir.length_squared()
		if len2 < 1e-10:
			# Seen from above it's a point (a vertical sliver): one sample, whole height
			var cx0 := int(floorf((a2.x - origin.x) * inv))
			var cz0 := int(floorf((a2.y - origin.y) * inv))
			if cx0 >= 0 and cz0 >= 0 and cx0 < fw and cz0 < fd:
				_add_span(spans, cx0 + fw * cz0, minf(a.y, minf(b.y, c.y)), maxf(a.y, maxf(b.y, c.y)))
			return
		# Each vertex's position along the line (0 at p0, 1 at p1)
		var sa := (a2 - p0).dot(dir) / len2
		var sb := (b2 - p0).dot(dir) / len2
		var sc := (c2 - p0).dot(dir) / len2
		var steps := ceili(sqrt(len2) * inv * 2.0) + 1
		var cur := -1                              # sample being filled
		var lo := INF
		var hi := -INF
		for k in steps + 1:
			var t := float(k) / steps
			var q := p0.lerp(p1, t)
			var cx := int(floorf((q.x - origin.x) * inv))
			var cz := int(floorf((q.y - origin.y) * inv))
			var i := cx + fw * cz
			if cx < 0 or cz < 0 or cx >= fw or cz >= fd:
				i = -1
			if i != cur:
				if cur >= 0 and lo <= hi:
					_add_span(spans, cur, lo, hi)     # done with the previous sample
				cur = i
				lo = INF
				hi = -INF
			if i < 0:
				continue
			# Vertical cut at t: where each edge crosses it
			var ys := _cut(a, b, sa, sb, t) + _cut(b, c, sb, sc, t) + _cut(c, a, sc, sa, t)
			for y in ys:
				lo = minf(lo, y)
				hi = maxf(hi, y)
		if cur >= 0 and lo <= hi:
			_add_span(spans, cur, lo, hi)
		return
	var x0 := maxi(int(floorf((minf(a2.x, minf(b2.x, c2.x)) - origin.x) * inv)), 0)
	var x1 := mini(int(floorf((maxf(a2.x, maxf(b2.x, c2.x)) - origin.x) * inv)), fw - 1)
	var z0 := maxi(int(floorf((minf(a2.y, minf(b2.y, c2.y)) - origin.y) * inv)), 0)
	var z1 := mini(int(floorf((maxf(a2.y, maxf(b2.y, c2.y)) - origin.y) * inv)), fd - 1)
	# Slope of the triangle's plane: over one sample (fcell wide) the height changes by up to
	# r on each side of the center. Steep surfaces fill that whole range (no vertical gap
	# between samples for a body to slip through); flat floors stay a single height.
	var gx := (a.y * (b2.y - c2.y) + b.y * (c2.y - a2.y) + c.y * (a2.y - b2.y)) / den
	var gz := (a.y * (c2.x - b2.x) + b.y * (a2.x - c2.x) + c.y * (b2.x - a2.x)) / den
	var r := (absf(gx) + absf(gz)) * fcell * 0.5
	var walkable := sqrt(gx * gx + gz * gz) <= max_tan   # flat enough to stand on
	var ymin := minf(a.y, minf(b.y, c.y))
	var ymax := maxf(a.y, maxf(b.y, c.y))
	const EPS := -1e-4
	for cz in range(z0, z1 + 1):
		var pz := origin.y + (cz + 0.5) * fcell
		for cx in range(x0, x1 + 1):
			var px := origin.x + (cx + 0.5) * fcell
			var l1 := ((b2.y - c2.y) * (px - c2.x) + (c2.x - b2.x) * (pz - c2.y)) / den
			var l2 := ((c2.y - a2.y) * (px - c2.x) + (a2.x - c2.x) * (pz - c2.y)) / den
			var l3 := 1.0 - l1 - l2
			if l1 < EPS or l2 < EPS or l3 < EPS:
				continue
			var h := l1 * a.y + l2 * b.y + l3 * c.y
			_add_span(spans, cx + fw * cz, maxf(h - r, ymin), minf(h + r, ymax))
			if walkable:
				var wi := cx + fw * cz
				var arr: PackedFloat32Array = walk_pts.get(wi, PackedFloat32Array())
				arr.append(h)
				walk_pts[wi] = arr


## Floors of one sample from its geometry: the heights of its walkable (not steep) surfaces
## where the agent fits (nothing solid from just above it up to agent_height). Highest
## first, merged when closer than min_layer_gap.
func _geometry_floors(pts: PackedFloat32Array, sp: PackedFloat32Array) -> PackedFloat32Array:
	var ok := PackedFloat32Array()
	for h in pts:
		var room := true
		for k in range(0, sp.size(), 2):
			if sp[k] < h + agent_height and sp[k + 1] > h + 0.15:
				room = false                       # something solid right above (its own
				break                              # sloped surface is within 0.15: ignored)
		if room:
			ok.append(h)
	if ok.is_empty():
		return ok
	return _floors(ok)


## A navigation mesh floor moved down onto the geometry top just below it (within
## snap_to_geometry), else unchanged.
func _snap_down(h: float, sp: PackedFloat32Array) -> float:
	var best := -INF
	for k in range(1, sp.size(), 2):
		var t := sp[k]                             # top of a span
		if t <= h + 0.02 and h - t <= snap_to_geometry and t > best:
			best = t
	return best if best > -INF else h


## Height(s) where the edge u-v (positions su, sv along the wall line) crosses position t.
func _cut(u: Vector3, v: Vector3, su: float, sv: float, t: float) -> Array:
	var d := sv - su
	if absf(d) < 1e-6:
		return [u.y, v.y] if absf(t - su) < 0.02 else []   # vertical edge, right here
	var f := (t - su) / d
	if f < -0.01 or f > 1.01:
		return []
	return [lerpf(u.y, v.y, clampf(f, 0.0, 1.0))]


func _add_span(spans: Dictionary, i: int, lo: float, hi: float) -> void:
	if spans.has(i):
		var arr: PackedFloat32Array = spans[i]
		arr.append(lo)
		arr.append(hi)
		spans[i] = arr                             # packed arrays are copies: store back
	else:
		spans[i] = PackedFloat32Array([lo, hi])


## A cell's solid spans: every span of its samples, sorted by bottom, overlapping or
## touching ones merged (thicker than a thin gap), at most block_layers (the highest
## ones merged together if there are more).
func _store_blocks(g: HeightGrid, cell: int, cx: int, cz: int, sub: int, fw: int,
		spans: Dictionary) -> void:
	var pairs: Array[Vector2] = []
	for sz in sub:
		for sx in sub:
			var fi := (cx * sub + sx) + fw * (cz * sub + sz)
			if spans.has(fi):
				var sp: PackedFloat32Array = spans[fi]
				for k in range(0, sp.size(), 2):
					pairs.append(Vector2(sp[k], sp[k + 1]))
	if pairs.is_empty():
		return
	pairs.sort_custom(func(u, v): return u.x < v.x)
	const GAP := 0.1                                 # thinner gaps are filled
	var merged: Array[Vector2] = [pairs[0]]
	for k in range(1, pairs.size()):
		var cur := merged[merged.size() - 1]
		if pairs[k].x <= cur.y + GAP:
			merged[merged.size() - 1] = Vector2(cur.x, maxf(cur.y, pairs[k].y))
		else:
			merged.append(pairs[k])
	# Gaps the agent's body can't fit in block exactly like solid: merge them (no loss)
	var body := g.agent_height - g.body_margin - 0.02
	var m := 1
	while m < merged.size():
		if merged[m].x - merged[m - 1].y < body:
			merged[m - 1] = Vector2(merged[m - 1].x, maxf(merged[m - 1].y, merged[m].y))
			merged.remove_at(m)
		else:
			m += 1
	# Still too many: merge where the gap is smallest (the big free spaces, like the inside
	# of a room or a ship, are kept)
	while merged.size() > g.block_layers:
		var best := 1
		var best_gap := INF
		for j in range(1, merged.size()):
			var gap := merged[j].x - merged[j - 1].y
			if gap < best_gap:
				best_gap = gap
				best = j
		merged[best - 1] = Vector2(merged[best - 1].x, maxf(merged[best - 1].y, merged[best].y))
		merged.remove_at(best)
	var o := cell * g.block_layers * 2
	for k in merged.size():
		g.blocks[o + 2 * k] = merged[k].x
		g.blocks[o + 2 * k + 1] = merged[k].y


# --- Baked grid ----------------------------------------------------------------------------

## The settings that change what _build_grid produces (a different value = rebake).
func _bake_signature() -> Dictionary:
	var slope := navigation_region.navigation_mesh.agent_max_slope \
			if navigation_region != null and navigation_region.navigation_mesh != null else 0.0
	return {
		"grid_cell": grid_cell, "max_layers": max_layers, "max_block_layers": max_block_layers,
		"min_layer_gap": min_layer_gap, "agent_height": agent_height,
		"walls_from_geometry": walls_from_geometry, "solid_edges": solid_edges,
		"snap_to_geometry": snap_to_geometry, "max_slope": slope,
	}


func _stale_settings(g: HeightGrid) -> PackedStringArray:
	var out := PackedStringArray()
	var now := _bake_signature()
	for k in now:
		if not g.bake_settings.has(k) or g.bake_settings[k] != now[k]:
			out.append(k)
	return out


## Settings that are only read while moving: applied to a loaded grid, no rebake needed.
func _apply_runtime_settings(g: HeightGrid) -> void:
	g.max_step_up = max_step_up
	g.player_only = only_controlled
	g.snap_radius = maxi(ceili(snap_radius / g.cell), 1)
	g.body_margin = clampf(g.cell, 0.1, max_step_up)


func _bake_to_file() -> void:
	if navigation_region == null or navigation_region.navigation_mesh == null:
		push_error("NavWorld: assign a NavigationRegion3D with a baked NavigationMesh first")
		return
	var t := Time.get_ticks_msec()
	var g := _build_grid()
	g.bake_settings = _bake_signature()
	var err := ResourceSaver.save(g, grid_file)
	if err != OK:
		push_error("NavWorld: could not save %s (error %d)" % [grid_file, err])
		return
	baked_grid = load(grid_file)
	grid = baked_grid
	print("NavWorld: grid baked and saved to %s in %.1f s" % [grid_file, (Time.get_ticks_msec() - t) / 1000.0])
	_draw(editor_preview)


# --- Editor preview ---------------------------------------------------------------------

func _refresh_editor() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if editor_preview and navigation_region != null:
		if use_baked and baked_grid != null and baked_grid.w > 0 and grid == null:
			grid = baked_grid                      # fast: the saved one
		else:
			grid = _build_grid()                   # refresh_preview / settings changed: build
		_draw(true)
	else:
		_draw(false)


## Rebakes the navigation mesh in the editor: refresh the preview afterwards.
func _on_region_baked() -> void:
	if Engine.is_editor_hint():
		_refresh_editor()


func _connect_region() -> void:
	if navigation_region != null and is_inside_tree() \
			and not navigation_region.bake_finished.is_connected(_on_region_baked):
		navigation_region.bake_finished.connect(_on_region_baked)


func _disconnect_region() -> void:
	if navigation_region != null and navigation_region.bake_finished.is_connected(_on_region_baked):
		navigation_region.bake_finished.disconnect(_on_region_baked)


# --- Dots (editor preview and in-game debug) -----------------------------------------------

func _draw(show: bool) -> void:
	_debug.visible = show and grid != null and grid.w > 0
	if not _debug.visible:
		return
	var lo := INF
	var hi := -INF
	for h in grid.heights:
		if not is_nan(h):
			lo = minf(lo, h)
			hi = maxf(hi, h)
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_POINTS)
	var n := 0
	for cz in grid.d:
		for cx in grid.w:
			for k in grid.layers:                  # every floor of the cell
				var h := grid.heights[(cx + grid.w * cz) * grid.layers + k]
				if is_nan(h):
					break
				var t := (h - lo) / maxf(hi - lo, 0.001)
				im.surface_set_color(Color(0.2, 0.6, 1.0).lerp(Color(1.0, 0.4, 0.2), t))   # low blue, high orange
				im.surface_add_vertex(Vector3(grid.origin.x + (cx + 0.5) * grid.cell, h + 0.05,
						grid.origin.y + (cz + 0.5) * grid.cell))
				n += 1
	if n == 0:
		im.surface_add_vertex(Vector3.ZERO)        # an empty surface is an error
	im.surface_end()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.use_point_size = true
	mat.point_size = 4.0
	_debug.mesh = im
	_debug.material_override = mat
	_debug.top_level = true                        # points are in world space
	_debug.global_transform = Transform3D.IDENTITY
	_debug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
