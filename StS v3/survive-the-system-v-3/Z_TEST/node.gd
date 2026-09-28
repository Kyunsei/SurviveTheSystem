extends Node

#this is Utility AI test!!!!

#step 1 -> geeting a curve for each inputs "consideration"
#step 2 -> assembling curve /"consideration" together for decision
#step 3 -> choosing the best decision


var weights : PackedFloat32Array

var c_e = 5.0 #internal thrive
var target: Vector2
var pos := Vector2(300,200)

###INPUT LIST
var input_mouse_score := 0.0
var input_energy_score := 0.0

###OUTPUT LIST
var action_move_score := 0.0
var action_eat_score := 0.0
var action_duplicate_score := 0.0



enum Type { LINEAR, POLYNOMIAL, LOGISTIC, LOGIT, EXPONENTIAL, BELL, STEP }
@export var type: Type = Type.LINEAR
@export var m: float = 1.0 ## slope (width for BELL)
@export var k: float = 1.0 ## exponent
@export var b: float = 0.0 ## vertical shift
@export var c: float = 0.0 ## horizontal shift (center / threshold)

func _process(delta: float) -> void:
	return
	target= get_viewport().get_mouse_position()
	###input
	var x = pos.distance_to(target)
	var x_norm = clampf((x - 0) / (1000 - 0), 0.0, 1.0)
	input_mouse_score  = 1- clampf( 1 * x_norm, 0.0,1.0)
	x = c_e
	x_norm = clampf((x - 0) / (5 - 0), 0.0, 1.0)
	input_energy_score = 1 - clampf( 1 * x_norm, 0.0,1.0)
	
	action_move_score = input_mouse_score * (1-input_energy_score) * 1
	action_eat_score = (1-input_mouse_score) * input_energy_score * 1
	action_duplicate_score = (1-input_mouse_score) * (1-input_energy_score) * 1
	
	if 	action_move_score > action_eat_score and action_move_score > action_duplicate_score :
		print("moving")
	if 	action_eat_score > action_move_score and action_eat_score > action_duplicate_score :
		print("eat")
		c_e += 0.05
	if 	action_duplicate_score > action_eat_score and action_duplicate_score > action_move_score :
		print("duplicate")	
		c_e = 0
	c_e -= 0.02
	#print("move %2f, eat %2f, duplicate %2f" % [action_move_score,action_eat_score,action_duplicate_score])



func score():
	pass

func evaluate(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	var y := 0.0
 
	match type:
		Type.LINEAR, Type.POLYNOMIAL:
			# y = m * (x - c)^k + b
			var d := x - c
			# pow() of a negative base with a fractional exponent is NaN
			if d < 0.0 and not is_equal_approx(k, roundf(k)):
				d = 0.0
			y = m * pow(d, k) + b
 
		Type.LOGISTIC:
			# y = k / (1 + e^(-m * (x - c))) + b
			y = k / (1.0 + exp(-m * (x - c))) + b
 
		Type.LOGIT:
			# y = (1/m) * ln(x / (1 - x)) + 0.5 + b
			var xx := clampf(x, 0.001, 0.999) # avoid infinity at 0 and 1
			if absf(m) < 0.0001:
				y = 0.5 + b
			else:
				y = log(xx / (1.0 - xx)) / m + 0.5 + b
 
		Type.EXPONENTIAL:
			# y = (e^(kx) - 1) / (e^k - 1) + b
			if absf(k) < 0.0001:
				y = x + b # limit as k -> 0 is linear
			else:
				y = (exp(k * x) - 1.0) / (exp(k) - 1.0) + b
 
		Type.BELL:
			# y = e^(-(x - c)^2 / (2 * sigma^2)), sigma = m
			var sigma := maxf(absf(m), 0.0001)
			y = exp(-pow(x - c, 2.0) / (2.0 * sigma * sigma)) + b
 
		Type.STEP:
			y = 1.0 if x >= c else 0.0
 
	if is_nan(y):
		return 0.0
	return clampf(y, 0.0, 1.0)
	
