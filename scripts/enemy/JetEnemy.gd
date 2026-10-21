extends FlyingEnemy
class_name JetEnemy

@onready var _hurtbox: Area3D = $Hurtbox

var _phase: float = 0.0
var _pass_target := Vector3.ZERO


func _on_flight_created() -> void:
	_phase = randf() * TAU
	_pass_target = _pick_pass_target()
	_hurtbox.collision_layer = COLLISION_LAYER


func _desired_velocity(_delta: float) -> Vector3:
	if global_position.distance_to(_pass_target) < 180.0:
		_pass_target = _pick_pass_target()
	var direction := (_pass_target - global_position).normalized()
	var side := direction.cross(Vector3.UP).normalized()
	return (
		direction + side * sin(_flight_age * 1.1 + _phase) * 0.35 * agility
	).normalized() * speed


func _pick_pass_target() -> Vector3:
	var angle := randf() * TAU
	var distance := randf_range(160.0, 420.0)
	var height := clampf(
		(global_position.y - target_position.y) * randf_range(0.4, 0.9),
		25.0, 600.0
	)
	return target_position + Vector3(
		cos(angle) * distance, height, sin(angle) * distance
	)


func _on_destroy() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.collision_layer = 0
