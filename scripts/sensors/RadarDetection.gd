extends RefCounted
class_name RadarDetection

var position: Vector3
var error: float
var size_hint: float


func _init(at: Vector3, error_metres: float, apparent_size: float) -> void:
	position = at
	error = error_metres
	size_hint = apparent_size
