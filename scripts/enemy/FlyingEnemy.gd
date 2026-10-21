@abstract
extends AbstractEnemy
class_name FlyingEnemy

@export var speed: float = 85.0
@export_range(0.0, 1.0) var agility: float = 0.45
@export var target_position := Vector3.ZERO
@export var arrival_radius: float = 55.0
@export var contact_damage: float = 6.0

var _flight_age: float = 0.0


func _create() -> void:
	if velocity.length_squared() <= 0.000001:
		velocity = (target_position - global_position).normalized() * speed
	else:
		velocity = velocity.normalized() * speed
	_face_velocity()
	_on_flight_created()


func _on_think(delta: float) -> void:
	var offset := target_position - global_position
	if Vector2(offset.x, offset.z).length() < arrival_radius:
		request_destroy()
		reached_target.emit(contact_damage)
		return
	if global_position.y < 2.0:
		request_destroy()
		return

	_flight_age += delta
	_on_flight_step(delta)
	if _destroy_requested:
		return
	var desired := _desired_velocity(delta)
	var turn := lerpf(0.5, 5.0, agility) * delta
	velocity = velocity.lerp(desired, clampf(turn, 0.0, 1.0))
	if velocity.length_squared() > 0.000001:
		velocity = velocity.normalized() * speed
	global_position += velocity * delta
	var remaining := target_position - global_position
	if Vector2(remaining.x, remaining.z).length() > 4200.0:
		velocity = remaining.normalized() * speed
	_face_velocity()


func _face_velocity() -> void:
	if velocity.length_squared() <= 0.000001:
		return
	var direction := velocity.normalized()
	if absf(direction.dot(Vector3.UP)) < 0.985:
		look_at(global_position + direction, Vector3.UP)


func _on_flight_created() -> void:
	pass


func _on_flight_step(_delta: float) -> void:
	pass


@abstract
func _desired_velocity(delta: float) -> Vector3
