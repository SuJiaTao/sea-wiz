extends Node
class_name BlastDrift

@export var effects: EffectManager
@export var ballistics: BallisticManager
@export var radius_per_size: float = 18.0
@export var push_per_size: float = 40.0


func _ready() -> void:
	effects.shockwave.connect(_on_shockwave)


func _on_shockwave(position: Vector3, size: float) -> void:
	ballistics.push_in_radius(position, size * radius_per_size, size * push_per_size)
