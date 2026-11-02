extends Node
class_name MuzzleMotion

@export var turret: Turret
@export var carry: float = 6.0

var _last_position: Vector3
var _velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	_last_position = turret.muzzle.global_position


func _physics_process(delta: float) -> void:
	var position := turret.muzzle.global_position
	if delta > 0.0:
		_velocity = (position - _last_position) / delta
	_last_position = position


func carried_velocity() -> Vector3:
	return _velocity * carry
