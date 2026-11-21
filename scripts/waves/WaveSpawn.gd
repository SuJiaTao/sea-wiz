extends Resource
class_name WaveSpawn

@export var time: float = 0.0
@export var enemy_scene: PackedScene
@export var distance := Vector2(900.0, 1400.0)
@export var altitude := Vector2(80.0, 260.0)
@export var group: StringName = &""
@export var formation: Formation
## Share of runs in which this spawn turns up at all.
@export_range(0.0, 1.0) var chance: float = 1.0
