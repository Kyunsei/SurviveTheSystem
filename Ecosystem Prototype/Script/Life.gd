'''
Generic script to determine the behaviour of life forms.

It consists of:
	Inner ressources management
	Reproduction
	Behaviour
	Adpatation/ evolution
	Body part function
'''
extends Node

var life_scene = load("res://Scene/life_entity.tscn")


var maximun_life_entities = 5000

var Life_Matrix_Element = [] #contain element 
var Life_Matrix_PositionX = [] #tile position
var Life_Matrix_PositionY = [] #tileposition
var Life_Matrix_Element_in = [] #metabo rule: element taken from block
var Life_Matrix_Element_built = [] #metabo rule: element built from taken
var Life_Matrix_Element_out = [] #metabo rule: element expulse into block
var Life_Matrix_Par = [] #old list will be replaced
var Life_Matrix_Phenotype = [] #parameter who changes: PV, age, posX, posY, sizeX, sizeY
var Life_Matrix_Genotype = [] #set of rules variable 
var Life_Matrix_Check = [] #state of life -1 : dead, 0: not here, 1: alive, 2: to duplicate

var Sprite_list = []
var Life_Genome = [] #liste of the different genome

#Life parameter: Genome, PV, Age, PosX, PosY, sizeX, SizeY
#this is parameter index, just to be less lost with indexing
var pi_PV = 1
#var pi_Energy = 2
#var pi_Elements = 3
#var pi_LifeState = 4
var pi_Age = 2
#var pi_isAlive = 6
var pi_PosX = 3
var pi_PosY = 4
var pi_SizeX = 5
var pi_SizeY = 6
var pi_Cycle = 7
#var pi_ToUpdate = 9

var ParNumber = 8


#Life Genome : G_ID, SpriteList, MoveSpeed, Size, Strength, foodtype, energyLifeCycleCost ,agelimit, energyHomeostasisCost, metabospeed
#this is genome index, just to be less lost with indexing
var gi_Sprite = 0

var gi_Size = 1
var gi_ElementsIn = 2
var gi_ElementsBuilt= 3
var gi_ElementsOut= 4
var gi_MaxAge = 5
var gi_GrowthCycle = 6
var gi_MoveSpeed = 7


var gi_InnerTimer = 10


# GENOTYPIC RULES

var gri_maxage = 0
var gri_growthcycle = 1
var gri_movespeed = 2


var rulesNumber = 3
var cycleStateNumber = 5


#Life Brain : TODO


#func to help code

func Init_Genome():

	Life_Genome.resize(maximun_life_entities)
	
	#GRASS	
	var genome_index = 0
	var sprite = ["res://art/grass1.png","res://art/grass2.png","res://art/grass3.png","res://art/grass4.png","0"]
	var size = [1.,1.,1.,1.,1.] #SIZE
	var el_in = [2,0,0,0,0,0,0,0,0,0] #IN
	var el_built = [0,1,0,0,1,0,0,0,0,0] #BUILT
	var el_out = [0,0,0,0,1,0,0,0,0,0] #OUT
	var maxage = [500,500,500,500,500]
	var growthcycle = [2,4,6,0,0] #make seed/clone when at the end only
	var movespeed = [0,0,0,0,0]
	Life_Genome[genome_index] = [sprite,size,el_in,el_built,el_out, maxage, growthcycle, movespeed]


	#SHEEP	
	var genome_index2 = 1
	var sprite2 = ["res://art/sheep1.png","res://art/sheep2.png","res://art/sheep3.png","res://art/sheep3.png","0"]
	var size2 = [1.,1.,1.,1.,0.] #SIZE
	var el_in2 = [0,2,0,0,0,0,0,0,0,0] #IN
	var el_built2 = [1,0,1,0,0,0,0,0,0,0] #BUILT
	var el_out2 = [1,0,0,0,0,1,0,0,0,0] #OUT
	var maxage2 = [500,500,500,500,500]
	var growthcycle2 = [2,3,4,0,0] #make seed/clone when at the end or reach 0
	var movespeed2 = [0,1,1,1,0]
	Life_Genome[genome_index2] = [sprite2,size2,el_in2,el_built2,el_out2, maxage2, growthcycle2, movespeed2]

func InitSprites():
	Sprite_list.resize(Life_Genome.size()*cycleStateNumber)
	Sprite_list.fill(0)
	var i = 0
	for g in Life_Genome:
		if g != null:
			for s in g[gi_Sprite]:
				if s != "0":
					Sprite_list[i] = load(s)
			
				i += 1
		else:
			i += 1
			


#Intern action


'func ProduceEnergy(par):
	
	var enoughElement = true
	#consumption
	for ei in range(par[pi_Elements].size()):
		if par[pi_Elements][ei] + par[0][gi_ElementsFlow][ei] < 0 :
			enoughElement = false
			#par[pi_Elements][e] = 0
			
	if enoughElement:
		par[pi_Energy] += 3
		for ei in range(par[pi_Elements].size()):
			par[pi_Elements][ei] += par[0][gi_ElementsFlow][ei] 
			World.Abioticsphere[ei] += par[0][gi_ElementsOut][ei] 
'

		



'func CheckDeath(par):
	if par[pi_Energy] <= 0:
		par[pi_isAlive] = false
	if par[pi_Age] > 10:
		par[pi_isAlive] = false
	'
'	
func Dying(par):
	if par[pi_isAlive] == false:
		par[pi_LifeState] = par[0][gi_Sprite].size()-1 #last life state is dead one
		par[pi_ToUpdate] = 1
		for e in range(par[pi_Elements].size()):
			if par[pi_Elements][e] > 0:
				if World.Element_state[e] == 0:
					World.Lithosphere[e] += 1#par[pi_Elements][e] 
					par[pi_Elements][e] -= 1
				if World.Element_state[e] == 1:
					World.Hydroshpere[e] += 1#par[pi_Elements][e] 
					par[pi_Elements][e] -= 1
				if World.Element_state[e] == 2:
					World.Atmosphere[e] += 1#par[pi_Elements][e] 
					par[pi_Elements][e] -= 1'
		
		
'func isDead(par):		
		if par[pi_Elements].all(func(e): return e == 0) :
			return true
		else :
			return false
'
	
#Extern ACTION TYPE
'
func TakeBlockElement(par):	
	#ROOT function
	var x = roundi(par[pi_PosX]/World.tile_size)
	var y = roundi(par[pi_PosY]/World.tile_size-1) #-1 for sprite offset
	var blockElement = 0
	var qte_transfer = 0
	var sizeFact = roundi(par[0][gi_Size][par[pi_LifeState]]/(World.tile_size/World.life_size_unit))
	for i in range(0,sizeFact):
		for j in range(0,sizeFact):
			if x+i >= 0 and y-j >= 0 and x+i < World.worldsize and y-j < World.worldsize :
				for e in range(par[pi_Elements].size()):
					blockElement = World.Block_Matrix[(x+i)*World.worldsize*par[pi_Elements].size()+(y-j)*par[pi_Elements].size() + e]
					par[pi_Elements][e] += blockElement
					World.Block_Matrix[(x+i)*World.worldsize*par[pi_Elements].size()+(y-j)*par[pi_Elements].size() + e] -=  blockElement
					World.Block_to_update.append([x+i,y-j])
'
'
func TakeSphereElement(par):
	for e in range(par[pi_Elements].size()):
		if World.Abioticsphere[e] >0:
			par[pi_Elements][e] += 1 
			World.Abioticsphere[e] -= 1  
		if World.Abioticsphere[e] >0:
			par[pi_Elements][e] += 1 
			World.Abioticsphere[e] -= 1  
		if World.Abioticsphere[e] >0:
			par[pi_Elements][e] += 1 
			World.Abioticsphere[e] -= 1  '



