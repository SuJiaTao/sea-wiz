extends FlyingEnemy
class_name GlideBombEnemy

@export var fall_speed: float = 55.0
@export var deck_radius: float = 45.0

@onready var _hurtbox: Area3D = $Hurtbox


func _on_flight_created() -> void:
	_hurtbox.collision_layer = COLLISION_LAYER
	speed = fall_speed


func _desired_velocity(_delta: float) -> Vector3:
	return (target_position - global_position).normalized() * speed


func _on_destroy() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.collision_layer = 0


func _on_arrival() -> void:
	if Vector2(target_position.x, target_position.z).length() <= deck_radius:
		super()
		return
	request_destroy()
	missed.emit(global_position)
