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

func build_sun_grid(position_array: PackedVector3Array) -> void:
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

func distribute_sun(energy_array,alive_array,active_array):
	for i in SUN_GRID.size():
		for s in range(cell_start[i], cell_start[i+1]):
			var idx :=  cell_items[s]
			if alive_array[idx] == 1 and active_array[idx] == 1:		
				energy_array[idx] += SUN_GRID[i] * 1 * 0.16
				#print(SUN_GRID[i])
				SUN_GRID[i] = 0

#index deadcell/alive cell are mixed

func run_world_simulation(alifemanager: AlifeManager, delta,simulation_speed):
	sun_usec = 0.0
	main_world_usec = 0.0
	var t0 := Time.get_ticks_usec()
	
	if SUN_on:
		var ts0 := Time.get_ticks_usec()
		build_sun_grid(alifemanager.position_array)
		SUN_GRID.fill(SUN_energy)
		distribute_sun(alifemanager.current_energy_array,alifemanager.alive_array,alifemanager.active_alife_array)
		sun_usec = Time.get_ticks_usec()-ts0
	
	main_world_usec = Time.get_ticks_usec()-t0
