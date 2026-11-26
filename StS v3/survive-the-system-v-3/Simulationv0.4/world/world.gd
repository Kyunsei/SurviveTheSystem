extends Node
class_name WorldManager

@export var controller : PlayerController
#------------Planete General
var size : Vector3
var default_size = Vector3(180,60,180) 
#var default_size = Vector3(240,60,240)
#var default_size = Vector3(340,60,340) 


enum Border { WRAP, WALL }
var border_type_x := Border.WRAP
var border_type_y := Border.WALL
var border_type_z := Border.WRAP

#------------SUN
##SUN #TODO check what is still use
var sun_usec := 0.0
var SUN_energy := 1.0
var SUN_GRID : PackedFloat32Array
var SUN_cell_size := Vector3(1.5,30.0,1.5) #/5
var SUN_GRID_W : int          # cells along x
var SUN_GRID_H : int          # cells along y
var SUN_GRID_D : int          # cells along z
var SUN_NUM_CELLS : int # = SUN_GRID_W * GRID_H * GRID_D

var SUN_stamp : PackedFloat32Array
	
	

#-------------live update
var world_size_change:= false


#-------------Rendered

var render3D :  WorldRender3D

#------------------SET_UP-----------------------------------------------

func init():
	$Render_World3D.setup(controller)
	
	_init_worldsize()
	_init_SUN()
	
	if !render3D:
		render3D = $Render_World3D


func _init_worldsize():
	if !size:
		size = default_size
	WorldWrap.configure(size,
		border_type_x == Border.WRAP,
		border_type_y == Border.WRAP,
		border_type_z == Border.WRAP)
func _init_SUN():
	var sun_dims := Vector3i((size / SUN_cell_size).ceil())
	SUN_GRID_W = sun_dims.x         # cells along x
	SUN_GRID_H = sun_dims.y       # cells along y
	SUN_GRID_D = sun_dims.z         # cells along z
	SUN_NUM_CELLS = SUN_GRID_W * SUN_GRID_H * SUN_GRID_D
	SUN_GRID.resize(SUN_NUM_CELLS)
	SUN_stamp.resize(SUN_NUM_CELLS)
	SUN_stamp.fill(0.0)
	SUN_GRID.fill(SUN_energy)

	
func render_world():
	render3D.DrawWorld(self)
	


#------------------MAIN------------------------------------------------
# Called when the node enters the scene tree for the first time.
func run_world_simulation(delta,dt,simulation_speed):
	#SUN_GRID.fill(SUN_energy)
	pass

func SUN_update():
	SUN_GRID.fill(SUN_energy)

#------------------OTHER------------------------------------------------
func set_sun_cell(new_size: Vector3):
	SUN_cell_size = new_size
	_init_SUN()


func set_world_size(new_size: Vector3):
	size = new_size
	_init_worldsize()
	_init_SUN()
	render_world()
	world_size_change = true
	
func set_world_border(axis:String, value : Border):
	match axis:
		"x":
			border_type_x = value
		"y":
			border_type_y = value
		"z":
			border_type_z = value
			
	_init_worldsize()
