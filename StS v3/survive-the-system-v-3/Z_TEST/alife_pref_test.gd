extends Node2D

var simulation_speed = 1
var n_start_life =1000 # 100
var running = false
var multithread = false
var _accum := 1.
var world: World

func init():
	world = $World
	world.init()

	$Visual/MultiMeshInstance2D.init()
	$AlifeManager.init(world)
	for i in n_start_life:
		$AlifeManager.Build_New_Life($AlifeManager.pick_random_position(Vector3(550,0,320))+Vector3(550,0,320),randf_range(0.0,5.0),0)
	'for i in n_start_life:
		$AlifeManager.Build_New_Life($AlifeManager.pick_random_position(Vector3(600,0,400))+Vector3(600,0,400),randf_range(0.0,5.0),1)
	for i in n_start_life:
		$AlifeManager.Build_New_Life($AlifeManager.pick_random_position(Vector3(600,0,400))+Vector3(600,0,400),randf_range(0.0,5.0),2)'
#	$AlifeManager.setup_chunk()
	
	$Visual/MultiMeshInstance2D.setup() #this was for buffer
	if $Visual/MultiMeshInstance2D.activated:
		$Visual/MultiMeshInstance2D.draw_new_instance($AlifeManager.pending_multimesh_drawn_id)
	#await get_tree().create_timer(1.0).timeout
	running = true
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if running :
		if simulation_speed > 0:
			run_simulation(delta)
			run_visualisation()
			
			_accum += delta
			if _accum >= 1.0:
				_accum = 0.0
				display_general_perf()
				diplay_alife_perf()
				display_world_perf()
			if Engine.get_frames_per_second() < 30:
				$AlifeManager.duplicate_on = false
				$simulation_UI/Alife/duplication.button_pressed = false
				#simulation_speed = 0
				#$simulation_UI/speed.text = "0"
			
	

var c := 0
func run_visualisation():
	if $Visual/MultiMeshInstance2D.activated:
		$Visual/MultiMeshInstance2D.draw_new_instance($AlifeManager.pending_multimesh_drawn_id)
		$Visual/MultiMeshInstance2D.erase_instance($AlifeManager.pending_multimesh_erase_id)

		$Visual/MultiMeshInstance2D.update_all_sequentially()
	if $Visual/MultiMesh_BIN.activated:
		$Visual/MultiMesh_BIN.update_all($World.SUN_GRID,$World.SUN_GRID_W,$World.SUN_GRID_H,$World.SUN_GRID_D,$World.SUN_cell_size,Color(0.71, 0.71, 0.348, 1.0))

var plant_only := false
func run_simulation(delta):
	$World.run_world_simulation($AlifeManager, delta, simulation_speed)
	if !multithread:
		#if $AlifeManager.AI_on:
		if plant_only:
			$AlifeManager.run_plant_simulation(delta,simulation_speed)
		else:
			$AlifeManager.run_simulation(delta,simulation_speed)

	else:
		if !plant_only:
			$AlifeManager.run_simulation_multithread(delta,simulation_speed)
		else:
			$AlifeManager.run_simulation_multithread2(delta,simulation_speed)

func display_world_perf():
	$simulation_UI/World/Label.text = "nLife - Active/Total : "+ str($AlifeManager.active_entity_count) +"/" + str($AlifeManager.entity_count)
	$simulation_UI/World/Label.text += "\n\nfunction \t msec  "
	$simulation_UI/World/Label.text += "\nmain_loop \t  %2d" % ($World.main_world_usec/1000.0)
	$simulation_UI/World/Label.text += "\nSUN \t  %2d" % ($World.sun_usec/1000.0)


func display_general_perf() -> void:
			%Label.text = "Duplication stop when reaching <30 FPS \n"
			%Label.text += "\nFPS: " + str(Engine.get_frames_per_second())
			%Label.text += "\nAlife_system:  %2d" % ($AlifeManager.main_usec/1000.0)
			%Label.text += "\nWorld_system:  %2d" % ($World.main_world_usec/1000.0)
			%Label.text += "\n\nnLife - Active/Total : "+ str($AlifeManager.active_entity_count) +"/" + str($AlifeManager.entity_count)
			#$Label.text += "\nEfficiency: %2d" % $AlifeManager.multithread_efficiency
			%Label.text += "\n\nRendering part \n \n"
			%Label.text += "\ndraw new msec: %2d" % ($Visual/MultiMeshInstance2D.draw_new_usec/1000.0)
			%Label.text += "\nUpdate all msec: %2d" % ($Visual/MultiMeshInstance2D.update_all_usec/1000.0)
func diplay_alife_perf() -> void:
	if simulation_speed > 0 :
		'_accum += delta
		if _accum >= 1.0:
			_accum = 0.0'
		$simulation_UI/Alife/Label.text = "nLife - Active/Total : "+ str($AlifeManager.active_entity_count) +"/" + str($AlifeManager.entity_count)
		$simulation_UI/Alife/Label.text += "\n\nfunction \t msec  "
		$simulation_UI/Alife/Label.text += "\nmain_loop \t  %2d" % ($AlifeManager.main_usec/1000.0)
		$simulation_UI/Alife/Label.text += "\nUtility_AI \t  %2d" % ($AlifeManager.uai_usec/1000.0)
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
		$ButtonUIshow.text = "Show Interface"
	else:
		$simulation_UI.show()
		$ButtonUIshow.text = "Hide Interface"


func _on_button_visualisation_toggled(toggled_on: bool) -> void:
	$Visual/MultiMeshInstance2D.activated = toggled_on
	if toggled_on:
		$Visual/MultiMeshInstance2D.show()
	else:
		$Visual/MultiMeshInstance2D.hide()

func _on_update_frame_text_submitted(new_text: String) -> void:
	$Visual/MultiMeshInstance2D.update_on_n_frame = int(new_text)


func _on_ai_on_o_ft_toggled(toggled_on: bool) -> void:
	$AlifeManager.AI_on = toggled_on


func _on_binsize_text_submitted(new_text: String) -> void:
	$AlifeManager.cell_size = float(new_text)
	$AlifeManager.init_GRID($World.size)
	#$AlifeManager.set_bin


func _on_bin_onoff_toggled(toggled_on: bool) -> void:
	$AlifeManager.bin_on = toggled_on


func _on_button_bin_visualisation_2_toggled(toggled_on: bool) -> void:
	$Visual/MultiMesh_BIN.init($World.SUN_cell_size)
	$Visual/MultiMesh_BIN.activated = toggled_on
		


func _on_button_1_toggled(toggled_on: bool) -> void:
	$simulation_UI/Alife.visible = toggled_on
	#$simulation_UI/World.visible = false
	#$simulation_UI/Rendering.visible = false
	if toggled_on:
		$simulation_UI/Panel/HBoxContainer/Button_3.button_pressed = false
		$simulation_UI/Panel/HBoxContainer/Button_2.button_pressed = false

func _on_button_2_toggled(toggled_on: bool) -> void:
	$simulation_UI/World.visible = toggled_on
	#$simulation_UI/Alife.visible = false
	#$simulation_UI/Rendering.visible = false
	if toggled_on:
		$simulation_UI/Panel/HBoxContainer/Button_1.button_pressed = false
		$simulation_UI/Panel/HBoxContainer/Button_3.button_pressed = false

func _on_button_3_toggled(toggled_on: bool) -> void:
	$simulation_UI/Rendering.visible = toggled_on
		#$simulation_UI/World.visible = false
		#$simulation_UI/Alife.visible = false
	if toggled_on:

		$simulation_UI/Panel/HBoxContainer/Button_1.button_pressed = false
		$simulation_UI/Panel/HBoxContainer/Button_2.button_pressed = false


func _on_duplication_toggled(toggled_on: bool) -> void:
	$AlifeManager.duplicate_on = toggled_on


func _on_world_y_text_submitted(new_text: String) -> void:
	$World.size.y = float(new_text)
	$World.init()
	$AlifeManager.init_GRID($World.size)


func _on_world_z_text_submitted(new_text: String) -> void:
	$World.size.z = float(new_text)
	$World.init()
	$AlifeManager.init_GRID($World.size)


func _on_world_x_text_submitted(new_text: String) -> void:
	$World.size.x = float(new_text)
	$World.init()
	$AlifeManager.init_GRID($World.size)


func _on_plant_on_toggled(toggled_on: bool) -> void:
	plant_only = toggled_on


func _on_check_button_toggled(toggled_on: bool) -> void:
	$World.SUN_on = toggled_on
	
func _on_sunenergy_text_submitted(new_text: String) -> void:
	$World.SUN_energy = float(new_text)

func _on_sun_x_text_submitted(new_text: String) -> void:
	$World.SUN_cell_size.x = float(new_text)
	$World.init_SUN_GRID()

func _on_sun_y_text_submitted(new_text: String) -> void:
	$World.SUN_cell_size.y = float(new_text)
	$World.init_SUN_GRID()

func _on_sun_z_text_submitted(new_text: String) -> void:
	$World.SUN_cell_size.z = float(new_text)
	$World.init_SUN_GRID()


func _on_remove_on_toggled(toggled_on: bool) -> void:
	$AlifeManager.remove_on = toggled_on
