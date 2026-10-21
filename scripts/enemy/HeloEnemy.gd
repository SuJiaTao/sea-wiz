extends FlyingEnemy
class_name HeloEnemy

@export var standoff_range := Vector2(260.0, 520.0)

@onready var _hurtbox: Area3D = $Hurtbox
@onready var _rotor: Node3D = $Visuals/Rotor
@onready var _tail_rotor: Node3D = $Visuals/TailRotor

var _phase: float = 0.0
var _standoff: float = 0.0


func _on_flight_created() -> void:
	_phase = randf() * TAU
	_standoff = randf_range(standoff_range.x, standoff_range.y)
	_hurtbox.collision_layer = COLLISION_LAYER


func _on_flight_step(delta: float) -> void:
	_rotor.rotate_y(delta * 60.0)
	_tail_rotor.rotate_y(delta * 90.0)


func _desired_velocity(_delta: float) -> Vector3:
	var offset := target_position - global_position
	var direction := offset.normalized()
	if Vector2(offset.x, offset.z).length() < _standoff:
		var side := direction.cross(Vector3.UP).normalized()
		direction = (
			direction * 0.35 + side * sin(_flight_age * 0.5 + _phase) * 0.9
		).normalized()
	direction.y += sin(_flight_age * 1.4 + _phase) * 0.12
	return direction.normalized() * speed


func _on_destroy() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.collision_layer = 0
