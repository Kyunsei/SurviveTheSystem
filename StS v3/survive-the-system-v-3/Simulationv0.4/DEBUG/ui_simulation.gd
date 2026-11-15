extends CanvasLayer

@export var alifemanager : AlifeManager
@export var world : WorldManager
@export var render: AlifeRendererManager
@export var simulation_manager: SimulationManager


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print_system_info() # Replace with function body.
	connect_crossref()

func connect_crossref():
	$DEBUG_Settings.world  = world
	$DEBUG_Settings.alifemanager = alifemanager
	$DEBUG_Settings.render  = render
	
	$DEBUG_graph.world  = world
	$DEBUG_graph.alifemanager = alifemanager
	$DEBUG_graph.render  = render
	
	$SPEED.simulation_manager = simulation_manager


func display_performance(am_usec:float, world_usec:float, render_usec:float) -> void:
			$Label.display_performance(am_usec, world_usec, render_usec)	

func print_system_info() -> void:
	print("=== SYSTEM ===")
	print("OS: ", OS.get_name(), " ", OS.get_version())
	print("Model: ", OS.get_model_name())
	print("Godot: ", Engine.get_version_info().string)

	print("=== CPU ===")
	print("Processor: ", OS.get_processor_name())
	print("Cores (logical): ", OS.get_processor_count())

	print("=== MEMORY ===")
	var mem := OS.get_memory_info()
	print("RAM total: ", String.humanize_size(mem["physical"]))
	print("RAM available: ", String.humanize_size(mem["available"]))

	print("=== GPU ===")
	print("GPU: ", RenderingServer.get_video_adapter_name())
	print("Vendor: ", RenderingServer.get_video_adapter_vendor())
	print("API: ", RenderingServer.get_video_adapter_api_version())
	print("Renderer: ", ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	print("VRAM used: ", String.humanize_size(int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))))

	print("=== SCREEN ===")
	print("Resolution: ", DisplayServer.screen_get_size())
	print("Refresh rate: ", DisplayServer.screen_get_refresh_rate(), " Hz")
