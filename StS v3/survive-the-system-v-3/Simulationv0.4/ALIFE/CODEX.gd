extends RefCounted
class_name ALIFE_CODEX

var species_list :Array[ALIFE]
var ref : Dictionary = {}
var species := {}


func _init():
	species_list.clear()
	species = {}
	build_species(ALIFE_GRASS.new())
	build_species(ALIFE_TREE.new())
	build_species(ALIFE_CLOVERMOSS.new())
	build_species(ALIFE_GLOWBERRY.new())
	build_species(ALIFE_SPIKYFLOWER.new())
	build_species(ALIFE_BUGSHEEP.new())
	build_species(ALIFE_SPIDERCRAB.new())
	build_species(ALIFE_CATRONAUTE.new())
	
	#apparently object are here too...
	#build_species(ALIFE_SEEDBAG.new())
	build_species(ALIFE_VACUUM.new())



	
func build_species(alife: ALIFE):
	species[alife.species_name] = alife

	#ref[alife.species_name] = species_list.size() 
	species_list.append(alife) #OLD NEED TO BE DELETED BUT FIRST CHANGE IT IN ALFIEMANGER
	

	
