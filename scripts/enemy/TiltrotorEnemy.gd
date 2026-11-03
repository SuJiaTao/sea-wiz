extends FlyingEnemy
class_name TiltrotorEnemy

const NACELLE_FORWARD := deg_to_rad(-90.0)
const NACELLE_UP := 0.0
const WEAVE_RATE := 0.5
const WEAVE_SIDE := 0.9
const CLOSE_IN_SHARE := 0.35
const BOB_RATE := 1.2
const BOB_DEPTH := 0.1

@export var cruise_speed: float = 150.0
@export var hover_speed: float = 48.0
@export var convert_range := Vector2(500.0, 1100.0)
@export var standoff_range := Vector2(280.0, 480.0)
@export var rotor_spin: float = 50.0
@export var nacelles: Array[Node3D] = []
@export var rotors: Array[Node3D] = []

var _phase: float = 0.0
var _standoff: float = 0.0
var _hover: float = 0.0

@onready var _hurtbox: Area3D = $Hurtbox


func _on_flight_created() -> void:
	_phase = randf() * TAU
	_standoff = randf_range(standoff_range.x, standoff_range.y)
	_hurtbox.collision_layer = COLLISION_LAYER
	speed = cruise_speed


func _on_flight_step(delta: float) -> void:
	var offset := target_position - global_position
	var distance := Vector2(offset.x, offset.z).length()
	_hover = 1.0 - smoothstep(convert_range.x, convert_range.y, distance)
	speed = lerpf(cruise_speed, hover_speed, _hover)
	for nacelle in nacelles:
		nacelle.rotation.x = lerpf(NACELLE_FORWARD, NACELLE_UP, _hover)
	for rotor in rotors:
		rotor.rotate_y(rotor_spin * delta)


func _desired_velocity(_delta: float) -> Vector3:
	var offset := target_position - global_position
	var direction := offset.normalized()
	if _hover > 0.5 and Vector2(offset.x, offset.z).length() < _standoff:
		var side := direction.cross(Vector3.UP).normalized()
		direction = (
			direction * CLOSE_IN_SHARE + side * sin(_flight_age * WEAVE_RATE + _phase) * WEAVE_SIDE
		).normalized()
	direction.y += sin(_flight_age * BOB_RATE + _phase) * BOB_DEPTH * _hover
	return direction.normalized() * speed


func _on_destroy() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.collision_layer = 0
