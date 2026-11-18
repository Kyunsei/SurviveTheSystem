extends RefCounted
class_name ALIFE_CODEX

var species_list :Array[ALIFE]
var alife_dic : Dictionary

func _init():
	var grass := ALIFE_GRASS.new()
	species_list.append(grass)

	var tree := ALIFE_TREE.new()
	species_list.append(tree)

	var moss := ALIFE_CLOVERMOSS.new()
	species_list.append(moss)
	
	var berry := ALIFE_GLOWBERRY.new()
	species_list.append(berry)
	
	var flower := ALIFE_SPIKYFLOWER.new()
	species_list.append(flower)
	
	var sheep := ALIFE_BUGSHEEP.new()
	species_list.append(sheep)
	
func build_species(Alife:ALIFE):
	var al :ALIFE = Alife.new()
	species_list.append(al)
	
	

	
