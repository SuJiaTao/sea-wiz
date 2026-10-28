extends RefCounted
class_name DecoyFlare

const GRAVITY: float = 9.81

var age: float = 0.0
var burn_time: float

var burning: bool:
	get:
		return age < burn_time

var position: Vector3:
	get:
		return _position_at(age)

var _origin: Vector3
var _launch: Vector3
var _drag: float


func _init(origin: Vector3, launch: Vector3, drag: float, burn_seconds: float) -> void:
	_origin = origin
	_launch = launch
	_drag = drag
	burn_time = burn_seconds


func advance(delta: float) -> void:
	age += delta


func _position_at(time: float) -> Vector3:
	var terminal := Vector3.DOWN * GRAVITY / _drag
	return _origin + terminal * time + (_launch - terminal) * (1.0 - exp(-_drag * time)) / _drag
