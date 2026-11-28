extends Resource
class_name NpcData
## One NPC: who it is, what it says, how it moves. Make one .tres per NPC
## (FileSystem: right click > New > Resource > NpcData) and assign it to an NpcSpot.

@export var display_name := "Stranger"
## Shown next to the text (optional).
@export var portrait: Texture2D

@export_group("Dialogue")
## Said the first time you talk to it, one line per entry (Action / Space / click: next).
@export var first_lines: PackedStringArray = ["Hello there!"]
## Said every time after that (empty = first_lines again).
@export var repeat_lines: PackedStringArray = []

@export_group("Movement")
## Wanders around its spot, never further than this (0 = stands still).
@export var wander_radius := 3.0
@export var wander_speed := 1.5
