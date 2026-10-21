extends FlyingEnemy
class_name SeaSkimmerEnemy

@export var cruise_altitude: float = 12.0

@onready var _hurtbox: Area3D = $Hurtbox


func _on_flight_created() -> void:
	_hurtbox.collision_layer = COLLISION_LAYER


func _desired_velocity(_delta: float) -> Vector3:
	var offset := target_position - global_position
	var direction := Vector3(offset.x, 0.0, offset.z).normalized()
	direction.y = clampf(
		(target_position.y + cruise_altitude - global_position.y) * 0.02,
		-0.25, 0.25
	)
	return direction.normalized() * speed


func _on_destroy() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.collision_layer = 0
