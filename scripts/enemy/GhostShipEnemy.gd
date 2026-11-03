extends FlyingEnemy
class_name GhostShipEnemy

const WEAVE_RATE := 0.2
const WEAVE_SIDE := 0.8
const CLOSE_IN_SHARE := 0.4
const ROLL_RATE := 0.7
const ROLL_DEPTH_DEG := 6.0
const HEAVE_RATE := 0.9
const HEAVE_DEPTH := 0.15
const LANTERN_FLICKER := Vector2(0.6, 1.2)

@export var standoff_range := Vector2(320.0, 520.0)
@export var lanterns: Array[Node3D] = []

var _phase: float = 0.0
var _standoff: float = 0.0

@onready var _hurtbox: Area3D = $Hurtbox


func _on_flight_created() -> void:
	_phase = randf() * TAU
	_standoff = randf_range(standoff_range.x, standoff_range.y)
	_hurtbox.collision_layer = COLLISION_LAYER


func _on_flight_step(_delta: float) -> void:
	visuals.rotation.z = deg_to_rad(ROLL_DEPTH_DEG) * sin(_flight_age * ROLL_RATE + _phase)
	for lantern in lanterns:
		lantern.scale = Vector3.ONE * randf_range(LANTERN_FLICKER.x, LANTERN_FLICKER.y)


func _desired_velocity(_delta: float) -> Vector3:
	var offset := target_position - global_position
	var direction := offset.normalized()
	if Vector2(offset.x, offset.z).length() < _standoff:
		var side := direction.cross(Vector3.UP).normalized()
		direction = (
			direction * CLOSE_IN_SHARE + side * sin(_flight_age * WEAVE_RATE + _phase) * WEAVE_SIDE
		).normalized()
	direction.y += sin(_flight_age * HEAVE_RATE + _phase) * HEAVE_DEPTH
	return direction.normalized() * speed


func _on_destroy() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.collision_layer = 0
