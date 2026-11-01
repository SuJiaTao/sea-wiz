extends RefCounted
class_name LensDroplet

var position: Vector2
var radius: float
var life: float
var age: float = 0.0

var strength: float:
	get:
		return clampf(1.0 - age / life, 0.0, 1.0)


func _init(at: Vector2, size: float, lifetime: float) -> void:
	position = at
	radius = size
	life = lifetime
