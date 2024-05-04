extends Sprite2D


var INDEX = 0
var element_str = ""
var display = false
var current_cycle = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
		element_str = ""
		for e in range(5):			
			element_str  = element_str + str("%.2f" % Life.Life_Matrix_Element[10*INDEX + e]) + " " 
			#element_str  = element_str + str("%.2f" % Life.Life_Matrix_Element_out[10*INDEX + e]) + " " 
			#element_str = ""
		SetDebugLabel("PV: " + str("%.1f" %Life.Life_Matrix_Phenotype[INDEX*Life.ParNumber+1]) + " Age: " + str(Life.Life_Matrix_Phenotype[INDEX*Life.ParNumber+2]) + " Cycle: " + str(Life.Life_Matrix_Phenotype[INDEX*Life.ParNumber+7]) +  "\n" + element_str)
		FadingColor()		
		if isNewCycle():
			SetSprite()
		#Set color


func SetSprite():
	var sprite = Life.Life_Genome[Life.Life_Matrix_Phenotype[INDEX*Life.ParNumber]][Life.gi_Sprite][Life.Life_Matrix_Phenotype[INDEX*Life.ParNumber+7]]
	var size = Life.Life_Genome[Life.Life_Matrix_Phenotype[INDEX*Life.ParNumber]][Life.gi_Size][Life.Life_Matrix_Phenotype[INDEX*Life.ParNumber+7]]
	#var sizey = Life.Life_Genome[Life.Life_Matrix_Phenotype[INDEX*Life.ParNumber]][Life.gi_Sprite][Life.Life_Matrix_Phenotype[INDEX*Life.ParNumber+7]]
	offset.y = 0
	
	var genome_index = Life.Life_Matrix_Phenotype[INDEX*Life.ParNumber]

	texture = Life.Sprite_list[genome_index*Life.cycleStateNumber + Life.Life_Matrix_Phenotype[INDEX*Life.ParNumber+7] ] 
	'var	width = texture.get_width()
	var factor =  float(width/ World.life_size_unit / size)
	scale = Vector2(1/factor,1/factor)
	offset.y -= World.life_size_unit*size*factor
	$DebugLabel.scale = Vector2(factor,factor)'

func FadingColor():
		var tt = 1
		for e in range(10):
				var x = (Life.Life_Matrix_Element[INDEX*10 + e] - Life.Life_Matrix_Genotype[INDEX*3*5 + 1*5 + 0])
				x = x/Life.Life_Matrix_Genotype[INDEX*3*5 + 1*5 + 0]
				x = x *(Life.Life_Matrix_Element_built[INDEX*10+e] - Life.Life_Matrix_Element_out[INDEX*10+e])
				tt += x
		tt = min(1,tt)
		#var x = Life.Life_Matrix_Phenotype[INDEX*Life.ParNumber+1]/100
		var col = lerp(Color(0,0,0), Color(1,1,1), tt)
		modulate = col

func isNewCycle():
	if current_cycle != Life.Life_Matrix_Phenotype[INDEX*Life.ParNumber + Life.pi_Cycle]:
		return true
	else:
		return false

	#print(offset.y)
	#position.y -= World.life_size_unit*size*factor

func SetDebugLabel(text):
	$DebugLabel.text = text



func _on_area_2d_mouse_entered():
	$DebugLabel.show() # Replace with function body.


func _on_area_2d_mouse_exited():
	$DebugLabel.hide() # Replace with function body. # Replace with function body.
