extends FlyingEnemy
class_name FallingTitanEnemy

const SPLASH_HEIGHT := 8.0

@export var fall_speed := Vector2(160.0, 420.0)
@export var fall_acceleration: float = 45.0
@export var tumble_rate: float = 0.25
@export var splash_spread := Vector2(450.0, 1100.0)

@onready var _hurtbox: Area3D = $Hurtbox


func _on_flight_created() -> void:
	_hurtbox.collision_layer = COLLISION_LAYER
	var bearing := randf() * TAU
	var reach := randf_range(splash_spread.x, splash_spread.y)
	target_position = Vector3(cos(bearing) * reach, 0.0, sin(bearing) * reach)
	speed = fall_speed.x


func _on_flight_step(delta: float) -> void:
	if global_position.y <= SPLASH_HEIGHT:
		_on_arrival()
		return
	speed = move_toward(speed, fall_speed.y, fall_acceleration * delta)
	visuals.rotate_z(tumble_rate * delta)


func _desired_velocity(_delta: float) -> Vector3:
	return (target_position - global_position).normalized() * speed


func _on_arrival() -> void:
	request_destroy()
	missed.emit(Vector3(global_position.x, target_position.y, global_position.z))


func _on_destroy() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.collision_layer = 0
