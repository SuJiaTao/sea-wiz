extends Node
class_name ShipRocking

@export var vessel: Node3D
@export var sway: ShipSway

var _rest: Transform3D


func _ready() -> void:
	_rest = vessel.transform


func _process(_delta: float) -> void:
	vessel.transform = Transform3D(sway.basis(), Vector3.ZERO) * _rest
