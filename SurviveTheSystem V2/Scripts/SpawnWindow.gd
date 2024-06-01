extends CanvasLayer

var current_cycle = 0
var genome_ID = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$ColorRect/Sprite2D.texture = Life.Genome[genome_ID]["sprite"][current_cycle]




func _on_buttonleft_genome_pressed():
	genome_ID -= 1
	genome_ID = max(0,genome_ID) 
	$ColorRect/GenomeBox/GenomeID.text = str(genome_ID)
	var valuemax = Life.Genome[genome_ID]["sprite"].size()-1
	current_cycle = min(valuemax,current_cycle) 
	$ColorRect/CycleBox/CycleID.text = str(current_cycle)

func _on_button_right_genome_pressed():
	genome_ID += 1
	genome_ID = min(4,genome_ID)  
	$ColorRect/GenomeBox/GenomeID.text = str(genome_ID)
	var valuemax = Life.Genome[genome_ID]["sprite"].size()-1
	current_cycle = min(valuemax,current_cycle) 
	$ColorRect/CycleBox/CycleID.text = str(current_cycle)

func _on_buttonleft_cycle_pressed():
	current_cycle -= 1
	current_cycle = max(0,current_cycle)  
	$ColorRect/CycleBox/CycleID.text = str(current_cycle)


func _on_button_right_cycle_pressed():
	current_cycle += 1
	var valuemax = Life.Genome[genome_ID]["sprite"].size()-1
	current_cycle = min(valuemax,current_cycle)  
	$ColorRect/CycleBox/CycleID.text = str(current_cycle)


func _on_button_pressed():
	$ColorRect.hide() # Replace with function body.
	$SpawnMenuButton.show()

func _on_spawn_menu_button_pressed():
	$ColorRect.show() # Replace with function body.
	$SpawnMenuButton.hide()

