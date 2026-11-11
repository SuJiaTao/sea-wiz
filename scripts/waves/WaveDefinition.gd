extends Resource
class_name WaveDefinition

@export var title: String = ""
@export var spawns: Array[WaveSpawn] = []
@export var if_engaged: WaveDefinition
@export var if_ignored: WaveDefinition
