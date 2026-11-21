extends RefCounted
class_name RadarDetection

var position: Vector3
var error: float
## The contact this return came from. Tracks follow one contact each, so two
## aircraft flying close never swap or merge on the scope.
var source: AbstractEnemy


func _init(at: Vector3, error_metres: float, from: AbstractEnemy) -> void:
	position = at
	error = error_metres
	source = from
