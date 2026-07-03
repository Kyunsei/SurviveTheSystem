extends Node

#THREAD
var simulation_thread : Thread
var thread_running := false
var thread_should_stop := false
var thread_delta : float = 0.0
var mutex := Mutex.new()
var thread_result_ready = false

var World_Thread : Thread
var world_semaphore :=Semaphore.new()
var world_done : bool = false
var world_done_semaphore :=Semaphore.new() 



var max_threads = OS.get_processor_count()
var threads_to_use = max(1, max_threads - 1)


func _ready() -> void:
	print(threads_to_use)
