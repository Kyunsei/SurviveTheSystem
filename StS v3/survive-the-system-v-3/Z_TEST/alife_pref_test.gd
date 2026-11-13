extends Node2D

var simulation_speed = 1
var n_start_life =10 # 100
var running = false
var multithread = false
var _accum := 1.
var world: World
var temp_world : World
var world_setting_change := false

#perf measure
var visu_usec := 0.0
var visu_draw_usec := 0.0
var visu_update_usec := 0.0
var visu_erase_usec := 0.0

func _ready() -> void:
	world = $World
	temp_world = world.duplicate()
	


func init():
	for mm in $AlifeManager.get_children():
		mm.queue_free()
	#world = $World
	world.init()
	temp_world = world.duplicate()
	#temp_world.init()
	$AlifeManager.init($World)
	$Visual.init($World,$AlifeManager)
	$simulation_UI/PopTracker.init($AlifeManager)
#	$Visual/MultiMeshInstance2D.init($AlifeManager,world) #OLD


	#if $AlifeManager.switch:
	var tt := Time.get_ticks_usec() 

	for sp in $AlifeManager.species_array:
		if sp == $AlifeManager.species_array[-1]:
			for i in 10:
				sp.Build_New_Life(sp.pick_random_position(Vector3(world.size.x/2,0,world.size.z/2),Vector3(world.size.x/2,0,world.size.z/2)),randf_range(0.0,5.0))

		else:
			for i in n_start_life:
					
				sp.Build_New_Life(sp.pick_random_position(Vector3(world.size.x/2,0,world.size.z/2),Vector3(world.size.x/2,0,world.size.z/2)),randf_range(0.0,5.0))

	var t := (Time.get_ticks_usec() - tt)/1000.0
	var e = n_start_life * $AlifeManager.species_array.size()
	var et = float(t)/float(e)
	$simulation_UI/RunGDScript/Label.text = "added " + str(e) + " entities for " +str(t) +"ms,  by enties is " +str(et)
	#print("added %d entities for %f ms,  by enties is %f" % [e, t,et])
	
	'else:
		for i in n_start_life:
			$AlifeManager.Build_New_Life($AlifeManager.pick_random_position(Vector3(550,0,320))+Vector3(550,0,320),randf_range(0.0,5.0),0)'
	
	'for i in n_start_life:
		$AlifeManager.Build_New_Life($AlifeManager.pick_random_position(Vector3(600,0,400))+Vector3(600,0,400),randf_range(0.0,5.0),1)
	for i in n_start_life:
		$AlifeManager.Build_New_Life($AlifeManager.pick_random_position(Vector3(600,0,400))+Vector3(600,0,400),randf_range(0.0,5.0),2)'
#	$AlifeManager.setup_chunk()
	'if !$AlifeManager.switch:
		$Visual/MultiMeshInstance2D.setup() #this was for buffer
		if $Visual/MultiMeshInstance2D.activated:
			$Visual/MultiMeshInstance2D.draw_new_instance($AlifeManager.pending_multimesh_drawn_id)
		#await get_tree().create_timer(1.0).timeout'
	running = true
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if running :
		if simulation_speed > 0:
			update_world_settings()
			run_simulation(delta)
			run_visualisation()
			
			_accum += delta
			if _accum >= 1.0:
				_accum = 0.0
				display_general_perf()
				diplay_alife_perf()
				display_world_perf()
				display_rendering_perf()
				$simulation_UI/PopTracker.update()

			if Engine.get_frames_per_second() < 30:
				$AlifeManager.duplicate_on = false
				%duplication.button_pressed = false
				#simulation_speed = 0
				#$simulation_UI/speed.text = "0"
			
	

var c := 0
func run_visualisation():

	visu_erase_usec = 0.0
	visu_draw_usec = 0.0
	visu_update_usec = 0.0
	$Visual.update_usec = 0
	$Visual.main_visu_usec = 0
	$Visual.write_usec = 0
	var t:= Time.get_ticks_usec()
	if $Visual.activated:
		if $AlifeManager.switch:
			$Visual.run_visualisation()
			'for s in $AlifeManager.species_array:
				pass
				$Visual.dosomething()
				var t1:= Time.get_ticks_usec()
				#s.rendering.rebuild_buffer()
				s.start_rendering_update()
				s.wait_rendering()
				s.update_renderer()'
				
				#s.renderer.upload(s.entity_count)
			's.rendering.draw_new_instance(s.pending_multimesh_drawn_id)
				visu_draw_usec += Time.get_ticks_usec()-t1
				t1= Time.get_ticks_usec()
				s.rendering.erase_instance(s.pending_multimesh_erase_id)
				visu_erase_usec += Time.get_ticks_usec()-t1
				t1= Time.get_ticks_usec()
				s.rendering.update_all_sequentially()'


		
		else:
			$Visual/MultiMeshInstance2D.draw_new_instance($AlifeManager.pending_multimesh_drawn_id)
			$Visual/MultiMeshInstance2D.erase_instance($AlifeManager.pending_multimesh_erase_id)

			$Visual/MultiMeshInstance2D.update_all_sequentially()
			
	if visu_sun_flow_on:
		$Visual/MultiMesh_BIN.update_all($World.SUN_GRID,$World.SUN_GRID_W,$World.SUN_GRID_H,$World.SUN_GRID_D,$World.SUN_cell_size,Color(0.71, 0.71, 0.348, 1.0))
	if visu_sun_stamp_on:	
		$Visual/MultiMesh_BIN.update_all($AlifeManager.current_global_photosynthesis_rate,$World.SUN_GRID_W,$World.SUN_GRID_H,$World.SUN_GRID_D,$World.SUN_cell_size,Color(0.71, 0.71, 0.348, 1.0))

	if visu_field_on:
		var sp =$AlifeManager.species_array[ visu_sp_selected ]
		$Visual/MultiMesh_BIN.update_all(sp.FIELD_count,sp.FIELD_W,sp.FIELD_H,sp.FIELD_D,sp.field_cell_size, sp.colour,10, 0)
	if visu_field_diff_on:
		var sp =$AlifeManager.species_array[ visu_sp_selected ]
		$Visual/MultiMesh_BIN.update_all(sp.FIELD_c_diffused,sp.FIELD_W,sp.FIELD_H,sp.FIELD_D,sp.field_cell_size, sp.colour,20, 0)
	if visu_gradient_on:
		var sp =$AlifeManager.species_array[ visu_sp_selected ]
		var SCENT  #TODO
		#$Visual/MultiMesh_BIN.update_all(sp.FIELD_c_diffused,sp.FIELD_W,sp.FIELD_H,sp.FIELD_D,sp.field_cell_size, sp.colour,100, 0)
	if visu_flow_dir_diff_on:
		var sp =$AlifeManager.species_array[ visu_sp_selected ]
		$Visual/MultiMesh_BIN.update_all(sp.FIELD_v_diffused,sp.FIELD_W,sp.FIELD_H,sp.FIELD_D,sp.field_cell_size, sp.colour,20.0, 1)
	if visu_flow_dir_on:
		var sp =$AlifeManager.species_array[ visu_sp_selected ]
		$Visual/MultiMesh_BIN.update_all(sp.FIELD_velocity,sp.FIELD_W,sp.FIELD_H,sp.FIELD_D,sp.field_cell_size, sp.colour,10.0, 1)

	visu_usec = Time.get_ticks_usec() - t
	
var plant_only := false
func run_simulation(delta):
	$World.run_world_simulation($AlifeManager, delta, simulation_speed)
	if $AlifeManager.switch:
		$AlifeManager.run_simulation2(delta,simulation_speed)
	else:
		if !multithread:
			$AlifeManager.run_simulation(delta,simulation_speed)

		else:
			$AlifeManager.run_simulation_multithread(delta,simulation_speed)


func update_world_settings():
	#return
	
	if world_setting_change :
		#update world size and grid size to new value
		var ratio := Vector3.ONE
		for a in 3:
			if world.size[a] != 0.0:
				ratio[a] = world.new_size[a] / world.size[a]
		for sp in $AlifeManager.species_array:
			for i in sp.entity_count:
				sp.Stock_Life(i) #THIS can be changed by a reset of stamp layer only i guess 
		$AlifeManager.cell_size = $AlifeManager.new_cell_size
		$AlifeManager.init_GRID(world.size)
		world.init()
		$AlifeManager.current_global_photosynthesis_rate.resize(world.SUN_NUM_CELLS)

		#recalculate new grid map of alife
		
		for sp in $AlifeManager.species_array:
			for i in sp.entity_count:
				sp.position_array[i] = sp.position_array[i] * ratio
				sp.Release_Life(i)		
		world_setting_change = false
	
func display_world_perf():
	$simulation_UI/World/Label.text = "nLife - Active/Total : "+ str($AlifeManager.active_entity_count) +"/" + str($AlifeManager.entity_count)
	$simulation_UI/World/Label.text += "\nSUN grid size: %d " % $World.SUN_NUM_CELLS

	$simulation_UI/World/Label.text += "\n\nfunction \t msec  "
	$simulation_UI/World/Label.text += "\nmain_loop \t  %2d" % ($World.main_world_usec/1000.0)
	$simulation_UI/World/Label.text += "\nSUN_total \t  %2d" % ($World.sun_usec/1000.0)
	$simulation_UI/World/Label.text += "\nSUN_build \t  %2d" % ($World.build_usec/1000.0)
	$simulation_UI/World/Label.text += "\nSUN_fill \t  %2d" % ($World.fill_usec/1000.0)
	$simulation_UI/World/Label.text += "\nSUN_distribute \t  %2d" % ($World.distribute_usec/1000.0)



func display_rendering_perf():
	$simulation_UI/Rendering/Label.text = "\n\nfunction \t msec  "
	$simulation_UI/Rendering/Label.text += "\nmain \t  %2d" % ($Visual.main_visu_usec/1000.0)
	$simulation_UI/Rendering/Label.text += "\nwrite_buffer\t  %2d" % ($Visual.write_usec/1000.0)
	$simulation_UI/Rendering/Label.text += "\nupdate\t  %2d" % ($Visual.update_usec/1000.0)
	#$simulation_UI/Rendering/Label.text += "\nerase\t  %2d" % (visu_erase_usec/1000.0)

	

func display_general_perf() -> void:
			%Label.text = "Duplication stop when reaching <30 FPS \n"
			%Label.text += "\nFPS: " + str(Engine.get_frames_per_second())
			%Label.text += "\nAlife_system:  %2d" % ($AlifeManager.main_usec/1000.0)
			%Label.text += "\nWorld_system:  %2d" % ($World.main_world_usec/1000.0)
			%Label.text += "\nRendering_system:  %2d" % ($Visual.main_visu_usec/1000.0)

			%Label.text += "\n\nnLife - Active/Total : "+ str($AlifeManager.active_entity_count) +"/" + str($AlifeManager.entity_count)

func diplay_alife_perf() -> void:
	if simulation_speed > 0 :

		'_accum += delta
		if _accum >= 1.0:
			_accum = 0.0'
		$simulation_UI/Alife/Label.text = "nLife - Active/Total : "+ str($AlifeManager.active_entity_count) +"/" + str($AlifeManager.entity_count)
		$simulation_UI/Alife/Label.text += "\n\nfunction \t msec  "
		$simulation_UI/Alife/Label.text += "\nmain_loop \t  %2d" % ($AlifeManager.main_usec/1000.0)
		$simulation_UI/Alife/Label.text += "\nmultithread \t  %2d" % ($AlifeManager.multithread_usec/1000.0)
		$simulation_UI/Alife/Label.text += "\nmerge \t  %2d" % ($AlifeManager.merge_usec/1000.0)
		
		
		$simulation_UI/Alife/Label.text += "\n\nUtility_AI \t  %2d" % ($AlifeManager.uai_usec/1000.0)
		$simulation_UI/Alife/Label.text += "\nbin_screen \t  %2d" % ($AlifeManager.bin_screen_usec/1000.0)
		$simulation_UI/Alife/Label.text += "\nbin_action \t  %2d" % ($AlifeManager.bin_action_usec/1000.0)
		$simulation_UI/Alife/Label.text += "\nbin_update \t  %2d" % ($AlifeManager.bin_update_usec/1000.0)

		$simulation_UI/Alife/Label.text += "\n\nMultithread part \n \n"
		$simulation_UI/Alife/Label.text += "Thread used: " + str($AlifeManager.nThreadused) + "/" +  str(OS.get_processor_count())
		$simulation_UI/Alife/Label.text += "\nChunk size/count: " + str($AlifeManager.chunk_size) + "/" +  str($AlifeManager.chunk_count)
		$simulation_UI/Alife/Label.text += "\nmsec\n \t1 Thread \t %2d \n \t Total \t\t\t %2d" % [($AlifeManager.thread_usec/1000.0),($AlifeManager.total_thread_usec/1000.0)]		

func display_perf() -> void:
	if simulation_speed > 0 :
			%Label.text = "Simulation stop when reaching <10 FPS \n"
			%Label.text += "\nFPS: " + str(Engine.get_frames_per_second())
			%Label.text += "\nmsec:  %2d" % ($AlifeManager.main_usec/1000.0)
			%Label.text += "\nnLife - Active/Total : "+ str($AlifeManager.active_entity_count) +"/" + str($AlifeManager.entity_count)
		
			%Label.text += "\n\nMultithread part \n \n"
			%Label.text += "Thread used: " + str($AlifeManager.nThreadused) + "/" +  str(OS.get_processor_count())
			%Label.text += "\nChunk size/count: " + str($AlifeManager.chunk_size) + "/" +  str($AlifeManager.chunk_count)
			%Label.text += "\nmsec\n \t1 Thread \t %2d \n \t Total \t\t\t %2d" % [($AlifeManager.thread_usec/1000.0),($AlifeManager.total_thread_usec/1000.0)]
			#$Label.text += "\nEfficiency: %2d" % $AlifeManager.multithread_efficiency
			%Label.text += "\n\nRendering part \n \n"
			%Label.text += "draw new msec: %2d" % ($Visual/MultiMeshInstance2D.draw_new_usec/1000.0)
			%Label.text += "\nUpdate all msec: %2d" % ($Visual/MultiMeshInstance2D.update_all_usec/1000.0)

 

func _on_speed_text_submitted(new_text: String) -> void:
	simulation_speed = float(new_text)


func _on_nstart_life_text_submitted(new_text: String) -> void:
	n_start_life = int(new_text)


func _on_run_gd_script_pressed() -> void:
	init() 
	


func _on_run_gpu_pressed() -> void:
	pass # Replace with function body.


func _on_run_cpp_pressed() -> void:
	pass # Replace with function body.





func _on_line_edit_text_submitted(new_text: String) -> void:
	if int(new_text) > 0:
		$AlifeManager.nThread_max = min(int(new_text), OS.get_processor_count())
	$simulation_UI/nThreads.text = str($AlifeManager.nThread_max)


func _on_check_box_toggled(toggled_on: bool) -> void:
	multithread = toggled_on


func _on_max_life_text_submitted(new_text: String) -> void:
	$AlifeManager.maxLife = int(new_text)


 

func _on_button_u_ishow_pressed() -> void:
	if $simulation_UI.visible:
		$simulation_UI.hide()
		$CanvasLayer/ButtonUIshow.text = "Show Interface"
	else:
		$simulation_UI.show()
		$CanvasLayer/ButtonUIshow.text = "Hide Interface"


func _on_button_visualisation_toggled(toggled_on: bool) -> void:
	$Visual.activated = toggled_on
	if toggled_on:
		$Visual/Rendering2D.show()
		$Visual/Rendering3D.show()

	else:
		#$Visual.hide()
		$Visual/Rendering2D.hide()
		$Visual/Rendering3D.hide()



func _on_ai_on_o_ft_toggled(toggled_on: bool) -> void:
	$AlifeManager.AI_on = toggled_on


func _on_binsize_text_submitted(new_text: String) -> void:
	$AlifeManager.new_cell_size.x = float(new_text)
	$AlifeManager.new_cell_size.z = float(new_text)
	world_setting_change = true
	#$AlifeManager.init_GRID($World.size)
	#$AlifeManager.set_bin


func _on_bin_onoff_toggled(toggled_on: bool) -> void:
	$AlifeManager.bin_on = toggled_on



		


func _on_button_1_toggled(toggled_on: bool) -> void:
	$simulation_UI/Alife.visible = toggled_on
	#$simulation_UI/World.visible = false
	#$simulation_UI/Rendering.visible = false
	if toggled_on:
		$simulation_UI/World.visible = false
		$simulation_UI/Rendering.visible = false
		$simulation_UI/Panel/HBoxContainer/Button_3.button_pressed = false
		$simulation_UI/Panel/HBoxContainer/Button_2.button_pressed = false

func _on_button_2_toggled(toggled_on: bool) -> void:
	$simulation_UI/World.visible = toggled_on
	#$simulation_UI/Alife.visible = false
	#$simulation_UI/Rendering.visible = false
	if toggled_on:
		$simulation_UI/Alife.visible = false
		$simulation_UI/Rendering.visible = false
		$simulation_UI/Panel/HBoxContainer/Button_1.button_pressed = false
		$simulation_UI/Panel/HBoxContainer/Button_3.button_pressed = false

func _on_button_3_toggled(toggled_on: bool) -> void:
	$simulation_UI/Rendering.visible = toggled_on
		#$simulation_UI/World.visible = false
		#$simulation_UI/Alife.visible = false
	if toggled_on:
		$simulation_UI/Alife.visible = false
		$simulation_UI/World.visible = false
		$simulation_UI/Panel/HBoxContainer/Button_1.button_pressed = false
		$simulation_UI/Panel/HBoxContainer/Button_2.button_pressed = false


func _on_duplication_toggled(toggled_on: bool) -> void:
	$AlifeManager.duplicate_on = toggled_on


func _on_world_y_text_submitted(new_text: String) -> void:
	world.new_size.y = float(new_text)
	world_setting_change = true



func _on_world_z_text_submitted(new_text: String) -> void:
	world.new_size.z = float(new_text)
	world_setting_change = true



func _on_world_x_text_submitted(new_text: String) -> void:
	world.new_size.x = float(new_text)
	world_setting_change = true



func _on_plant_on_toggled(toggled_on: bool) -> void:
	plant_only = toggled_on


func _on_check_button_toggled(toggled_on: bool) -> void:
	$AlifeManager.bin_on = toggled_on

func _on_sunenergy_text_submitted(new_text: String) -> void:
	world.SUN_energy = float(new_text)

func _on_sun_x_text_submitted(new_text: String) -> void:
	world.new_SUN_cell_size.x = float(new_text)
	world_setting_change = true

func _on_sun_y_text_submitted(new_text: String) -> void:
	world.new_SUN_cell_size.y = float(new_text)
	world_setting_change = true

func _on_sun_z_text_submitted(new_text: String) -> void:
	world.new_SUN_cell_size.z = float(new_text)
	world_setting_change = true
	
	
func _on_x_text_submitted(new_text: String) -> void:
	$AlifeManager.new_cell_size.x = float(new_text)
	world_setting_change = true

func _on_y_text_submitted(new_text: String) -> void:
	$AlifeManager.new_cell_size.y = float(new_text)
	world_setting_change = true

func _on_z_text_submitted(new_text: String) -> void:
	$AlifeManager.new_cell_size.z = float(new_text)
	world_setting_change = true


func _on_remove_on_toggled(toggled_on: bool) -> void:
	$AlifeManager.remove_on = toggled_on


func _on_growth_on_toggled(toggled_on: bool) -> void:
	$AlifeManager.grow_on = toggled_on


func _on_multispecies_toggled(toggled_on: bool) -> void:
	simulation_speed = 0
	$simulation_UI/speed.text = "0"
	$AlifeManager.switch = toggled_on
	#init()
	#$AlifeManager.init(world)


func _on_n_species_text_submitted(new_text: String) -> void:
	$AlifeManager.n_species = int(new_text)


func _on_photosynthesis_toggled(toggled_on: bool) -> void:
	$AlifeManager.photosynthesis_on = toggled_on


func _on_photo_range_text_submitted(new_text: String) -> void:
	$AlifeManager.photo_range = float(new_text)


func _on_homeo_on_toggled(toggled_on: bool) -> void:
	$AlifeManager.homeostasis_on = toggled_on


func _on_dup_range_text_submitted(new_text: String) -> void:
	$AlifeManager.duplication_range = float(new_text)


func _on_check_diffusion_toggled(toggled_on: bool) -> void:
	$World.SUN_diffusion_on = toggled_on


func _on_check_stamp_agent_toggled(toggled_on: bool) -> void:
	$AlifeManager.agent_photo_stamp_on = toggled_on


func _on_fullrange_on_toggled(toggled_on: bool) -> void:
	$AlifeManager.agent_calculated_photo_value = toggled_on


func _on_fullrange_on_2_toggled(toggled_on: bool) -> void:
	$AlifeManager.grid_calculated_photo_value = toggled_on


var visu_sun_flow_on:= false
var visu_sun_stamp_on:= false
var visu_sun_value_on:= false

var visu_field_on := false
var visu_field_diff_on := false
var visu_gradient_on := false


var visu_sp_selected := 0

var visu_flow_dir_on:= false
var visu_flow_dir_diff_on:= false


func _on_stamp_toggled(toggled_on: bool) -> void:
	$Visual/MultiMesh_BIN.init($World.SUN_cell_size)
	visu_sun_stamp_on = toggled_on


func _on_flux_toggled(toggled_on: bool) -> void:
	$Visual/MultiMesh_BIN.init($World.SUN_cell_size)
	visu_sun_flow_on = toggled_on


func _on_value_toggled(toggled_on: bool) -> void:
	$Visual/MultiMesh_BIN.init($World.SUN_cell_size)
	visu_sun_value_on = toggled_on


func _on_photo_rate_text_submitted(new_text: String) -> void:
	$AlifeManager.photo_absorption_rate = float(new_text)


func _on_borderx_item_selected(index: int) -> void:
	world.border_type_x = index
	#world_setting_change	= true


func _on_bordery_item_selected(index: int) -> void:
	world.border_type_y = index
	#world_setting_change	= true


func _on_borderz_item_selected(index: int) -> void:
	world.border_type_z = index
	#world_setting_change	= true


func _on_interaction_onoff_toggled(toggled_on: bool) -> void:
	$AlifeManager.count_neighbour_on = toggled_on


func _on_field_count_toggled(toggled_on: bool) -> void:
	visu_field_on = toggled_on


func _on_field_toggled(toggled_on: bool) -> void:
	visu_field_diff_on = toggled_on


func _on_layer_text_submitted(new_text: String) -> void:
	$Visual/MultiMesh_BIN.current_layer = int(new_text)


func _on_sp_text_submitted(new_text: String) -> void:
	visu_sp_selected = clamp(int(new_text),0,$AlifeManager.species_array.size()-1)


func _on_dir_toggled(toggled_on: bool) -> void:
	visu_flow_dir_on = toggled_on



func _on_neigh_range_text_submitted(new_text: String) -> void:
	$AlifeManager.neighbour_view_range = float(new_text)


func _on_neigh_max_text_submitted(new_text: String) -> void:
	$AlifeManager.neighbour_max_count = int(new_text)


func _on_option_button_item_selected(index: int) -> void:
	$AlifeManager.flock_type = index


func _on_check_scent_button_toggled(toggled_on: bool) -> void:
	$AlifeManager.field_on = toggled_on


func _on_gradient_toggled(toggled_on: bool) -> void:
	visu_gradient_on = toggled_on


func _on_dir_diff_toggled(toggled_on: bool) -> void:
	visu_flow_dir_diff_on = toggled_on


func _on_allign_text_submitted(new_text: String) -> void:
	$AlifeManager.allignment = float(new_text)


func _on_sep_text_submitted(new_text: String) -> void:
	$AlifeManager.separation = float(new_text)


func _on_cohesion_text_submitted(new_text: String) -> void:
	$AlifeManager.cohesion = float(new_text)
