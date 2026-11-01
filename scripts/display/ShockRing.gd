extends RefCounted
class_name ShockRing

var origin: Vector3
var size: float
var age: float = 0.0


func _init(at: Vector3, blast_size: float) -> void:
	origin = at
	size = blast_size
