extends Node2D
class_name World

#TODO where sun is picked and where life are viusaly doesnt correspond

var size : Vector3
var default_size = Vector3(1100,20,640)
# Called when the node enters the scene tree for the first time.

var main_world_usec := 0.0


##SUN
var sun_usec := 0.0
var SUN_on := true
var SUN_energy := 1.0
var SUN_GRID : PackedFloat32Array
#var SUN_cell_size := 10.0
var SUN_cell_size := Vector3(10.0,20.0,10.0)

var SUN_GRID_W : int          # cells along x
var SUN_GRID_H : int          # cells along y
var SUN_GRID_D : int          # cells along z
var SUN_GRID_WD : int# = SUN_GRID_W * GRID_D
var SUN_GRID_WH : int #= SUN_GRID_W * GRID_H
var SUN_NUM_CELLS : int # = SUN_GRID_W * GRID_H * GRID_D

var bin_origin := Vector3.ZERO   # min corner of the grid in world space
var cell_start := PackedInt32Array()     # size NUM_CELLS + 1
var write_pos := PackedInt32Array()      # size NUM_CELLS (scratch)
var cell_items := PackedInt32Array()     # size = alife count
var current_cell_id := PackedInt32Array()  # size = alife count
var sorted_pos := PackedVector3Array()

var build_usec := 0.0
var fill_usec := 0.0
var distribute_usec := 0.0




func _ready() -> void:
	size = default_size
	init()



func init():
	init_SUN_GRID()
# Called every frame. 'delta' is the elapsed time since the previous frame.



func init_SUN_GRID():
	var sun_dims := Vector3i((size / SUN_cell_size).ceil())
	SUN_GRID_W = sun_dims.x         # cells along x
	SUN_GRID_H = sun_dims.y       # cells along y
	SUN_GRID_D = sun_dims.z         # cells along z
	SUN_GRID_WD = SUN_GRID_W * SUN_GRID_D
	SUN_GRID_WH = SUN_GRID_W * SUN_GRID_H
	SUN_NUM_CELLS = SUN_GRID_W * SUN_GRID_H * SUN_GRID_D
	cell_start.resize(SUN_NUM_CELLS + 1)
	write_pos.resize(SUN_NUM_CELLS)
	SUN_GRID.resize(SUN_NUM_CELLS)

func build_sun_grid2(position_array: PackedVector3Array) -> void:
	var n := position_array.size()
	current_cell_id.resize(n)
	cell_items.resize(n)
	sorted_pos.resize(n)
	cell_start.fill(0)
	#var inv := 1.0 / SUN_cell_size
	var inv := Vector3.ONE / SUN_cell_size   # (1/x, 1/y, 1/z)


	# 1. Count particles per cell
	for i in n:
		var p := (position_array[i] - bin_origin) * inv
		var cx := clampi(roundi(p.x), 0, SUN_GRID_W - 1)
		var cy := clampi(roundi(p.y), 0, SUN_GRID_H - 1)
		var cz := clampi(roundi(p.z), 0, SUN_GRID_D - 1)
		var c := cx + SUN_GRID_W * (cy + SUN_GRID_H * cz)   # inline, no second division
		current_cell_id[i] = c
		cell_start[c + 1] += 1


	# 2. Prefix sum -> start offset of each cell
	for c in SUN_NUM_CELLS:
		cell_start[c + 1] += cell_start[c]
		write_pos[c] = cell_start[c]

	# 3. Scatter indices and positions into sorted order
	for i in n:
		var c := current_cell_id[i]
		var w := write_pos[c]
		cell_items[w] = i
		sorted_pos[w] = position_array[i]
		write_pos[c] = w + 1

func build_sun_grid(global_position_array: PackedVector3Array) -> void:
	var n := global_position_array.size()
	current_cell_id.resize(n)
	cell_items.resize(n)
	sorted_pos.resize(n)
	cell_start.fill(0)
	#var inv := 1.0 / SUN_cell_size
	var inv := Vector3.ONE / SUN_cell_size   # (1/x, 1/y, 1/z)


	# 1. Count particles per cell
	for i in n:
		var p := (global_position_array[i] - bin_origin) * inv
		var cx := clampi(roundi(p.x), 0, SUN_GRID_W - 1)
		var cy := clampi(roundi(p.y), 0, SUN_GRID_H - 1)
		var cz := clampi(roundi(p.z), 0, SUN_GRID_D - 1)
		var c := cx + SUN_GRID_W * (cy + SUN_GRID_H * cz)   # inline, no second division
		current_cell_id[i] = c
		cell_start[c + 1] += 1


	# 2. Prefix sum -> start offset of each cell
	for c in SUN_NUM_CELLS:
		cell_start[c + 1] += cell_start[c]
		write_pos[c] = cell_start[c]

	# 3. Scatter indices and positions into sorted order
	for i in n:
		var c := current_cell_id[i]
		var w := write_pos[c]
		cell_items[w] = i
		sorted_pos[w] = global_position_array[i]
		write_pos[c] = w + 1


func distribute_sun_old(energy_array,alive_array,active_array):
	for i in SUN_GRID.size():
		for s in range(cell_start[i], cell_start[i+1]):
			var idx :=  cell_items[s]
			if alive_array[idx] == 1 and active_array[idx] == 1:	
				energy_array[idx] += SUN_GRID[i] * 1 * 0.16
				#print(SUN_GRID[i])
				SUN_GRID[i] = 0

func distribute_sun(alifem:AlifeManager):
	var sp_offset := alifem.global_species_offset
	var sp_array := alifem.species_array
	for i in SUN_GRID.size():
		var max_age := -1
		var age := 0
		var target_id : Vector2i #species, local id

		for s in range(cell_start[i], cell_start[i+1]):
			var gi :=  cell_items[s] 
			var si := sp_offset.bsearch(gi, false) - 1	
			var local_index := gi - sp_offset[si]
			var sp := sp_array[si]
			if sp.alive_array[local_index] == 1 and sp.active_alife_array[local_index] == 1:
				age = sp.current_age[local_index]
				if age > max_age:
					max_age = age
					target_id = Vector2(si,local_index)
				
		
		if target_id:
			sp_array[target_id.x].current_energy_array[target_id.y] += SUN_GRID[i] * 1 * 0.16
			SUN_GRID[i] = 0


#index deadcell/alive cell are mixed

func run_world_simulation(alifemanager: AlifeManager, delta,simulation_speed):
	sun_usec = 0.0
	main_world_usec = 0.0
	build_usec = 0.0	
	fill_usec = 0.0
	distribute_usec = 0.0
	var t0 := Time.get_ticks_usec()
	
	if SUN_on:
		var ts0 := Time.get_ticks_usec()
		build_sun_grid(alifemanager.global_position_array)
		build_usec = Time.get_ticks_usec() - ts0
		SUN_GRID.fill(SUN_energy)
		fill_usec = Time.get_ticks_usec() - (ts0 + build_usec)
		#sun_first_come(Vector3i(3,1,3),alifemanager)
		#TODO -> sun_first_come_disk(1.0,alifemanager)
		distribute_sun(alifemanager)
		distribute_usec = Time.get_ticks_usec() - (ts0 + build_usec + fill_usec)
		sun_usec = Time.get_ticks_usec()-ts0
	
	main_world_usec = Time.get_ticks_usec()-t0


const BIG := 0x7FFFFFFF

var min_id := PackedInt32Array()   # all size SUN_NUM_CELLS
var tmp_a := PackedInt32Array()
var tmp_b := PackedInt32Array()

func sun_first_come(r: Vector3i, alifemanger:AlifeManager) -> void:   # cube half-size in cells per axis, e.g. Vector3i(1,1,1)
	var W := SUN_GRID_W; var H := SUN_GRID_H; var D := SUN_GRID_D
	if min_id.size() != SUN_NUM_CELLS:
		min_id.resize(SUN_NUM_CELLS)

	# 1. lowest alive agent index per cell
	for c in SUN_NUM_CELLS:
		var m := BIG
		for s in range(cell_start[c], cell_start[c + 1]):
			var idx := cell_items[s]
			if alifemanger.alive_array[idx] == 1 and alifemanger.active_alife_array[idx] == 1:
				m = idx          # ascending order -> first alive is the lowest
				break
		min_id[c] = m

	# 2. separable cube min: x, then y, then z
	tmp_a = _min_pass(min_id, tmp_a, 1,     W, r.x)
	tmp_b = _min_pass(tmp_a,  tmp_b, W,     H, r.y)
	tmp_a = _min_pass(tmp_b,  tmp_a, W * H, D, r.z)   # tmp_a = owner of each sun cell

	# 3. owner takes the whole cell
	for g in SUN_NUM_CELLS:
		var owner := tmp_a[g]
		if owner != BIG and SUN_GRID[g] > 0.0:
			alifemanger.current_energy_array[owner] += SUN_GRID[g] * 0.16
			SUN_GRID[g] = 0.0


# 1D sliding min along one axis (stride 1 = x, W = y, W*H = z)
func _min_pass(src: PackedInt32Array, dst: PackedInt32Array, stride: int, L: int, r: int) -> PackedInt32Array:
	dst.resize(src.size())
	for c in src.size():
		var a := (c / stride) % L               # coordinate along this axis
		var lo := maxi(a - r, 0) - a
		var hi := mini(a + r, L - 1) - a
		var m := BIG
		for d in range(lo, hi + 1):
			m = mini(m, src[c + d * stride])
		dst[c] = m
	return dst


func sun_first_come_disk(r: float,alifemanager:AlifeManager) -> void:   # r in cells, e.g. 2.0
	if r != disk_r:
		build_disk(r)
	if min_id.size() != SUN_NUM_CELLS:
		min_id.resize(SUN_NUM_CELLS)
		_owner.resize(SUN_NUM_CELLS)
	var W := SUN_GRID_W; var H := SUN_GRID_H; var D := SUN_GRID_D
	var n_off := disk_off.size()

	# 1. lowest alive agent per cell (same as before)
	for c in SUN_NUM_CELLS:
		var m := BIG
		for s in range(cell_start[c], cell_start[c + 1]):
			var idx := cell_items[s]
			if alifemanager.alive_array[idx] == 1 and alifemanager.active_alife_array[idx] == 1:
				m = idx
				break
		min_id[c] = m

	# 2. owner = min over the disc in x/z, same y layer
	for z in D:
		for y in H:                      # H = 1 -> just y = 0
			var layer := W * (y + H * z)
			for x in W:
				var m := BIG
				for k in range(0, n_off, 2):
					var nx := x + disk_off[k]
					var nz := z + disk_off[k + 1]
					if nx < 0 or nz < 0 or nx >= W or nz >= D:
						continue
					m = mini(m, min_id[nx + W * (y + H * nz)])
				_owner[layer + x] = m

	# 3. owner takes the whole cell
	for g in SUN_NUM_CELLS:
		var o := _owner[g]
		if o != BIG and SUN_GRID[g] > 0.0:
			alifemanager.current_energy_array[o] += SUN_GRID[g] * 0.16
			SUN_GRID[g] = 0.0


var disk_off := PackedInt32Array()   # dx, dz pairs
var disk_r := -1.0
var _owner := PackedInt32Array()      # size SUN_NUM_CELLS

func build_disk(r: float) -> void:
	disk_off.clear()
	var ri := floori(r)
	for dz in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			if dx * dx + dz * dz <= r * r:
				disk_off.append(dx)
				disk_off.append(dz)
	disk_r = r
