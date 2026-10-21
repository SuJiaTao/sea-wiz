extends FlyingEnemy
class_name DroneEnemy

@onready var _hurtbox: Area3D = $Hurtbox

var _weave_phase: float = 0.0


func _on_flight_created() -> void:
	_weave_phase = randf() * TAU
	_hurtbox.collision_layer = COLLISION_LAYER


func _desired_velocity(_delta: float) -> Vector3:
	var direction := (target_position - global_position).normalized()
	var side := direction.cross(Vector3.UP).normalized()
	var up := side.cross(direction).normalized()
	var amplitude := 0.9 * agility
	return (
		direction
		+ side * sin(_flight_age * 1.9 + _weave_phase) * amplitude
		+ up * sin(_flight_age * 1.3 + _weave_phase * 1.7) * amplitude * 0.6
	).normalized() * speed


func _on_destroy() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.collision_layer = 0
