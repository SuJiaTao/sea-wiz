extends RefCounted
class_name ProjectileImpact

var enemy: Enemy
var position: Vector3
var point: Vector3
var normal := Vector3.UP
var fraction: float = 1.0


func _init(at: Vector3, target: Enemy = null) -> void:
	position = at
	point = at
	enemy = target
