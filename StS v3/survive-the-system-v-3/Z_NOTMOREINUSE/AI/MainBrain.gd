extends Node


#BEGINING UTILITY AI SYSTEM

var actions = []
var action_a  #class action
var input

func Choose_action():
	var best_score = 0
	var best_action = null
	for a in actions:
		var score = a.evaluate(input)
		if score > best_score:
			best_score = score
			best_action = a
			
	return best_action
		



func evaluate(inputs):
	print("cutom function")
	
func execute():
	#START NEW STATE?
	print("action done")
