@abstract
extends AbstractEnemy
class_name FlyingEnemy

const GRAVITY: float = 9.81
const MIN_SPEED_SQUARED: float = 0.000001
const NEAR_VERTICAL: float = 0.985

@export var speed: float = 85.0
@export_range(0.0, 1.0) var agility: float = 0.45
@export var target_position := Vector3.ZERO
@export var arrival_radius: float = 55.0
@export var contact_damage: float = 6.0
@export_range(0.0, 85.0) var max_bank_deg: float = 70.0
@export var bank_response: float = 3.0

var _flight_age: float = 0.0
var _bank: float = 0.0
var _heading := Vector3.ZERO


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
	_face_velocity(delta)


func _face_velocity(delta: float = 0.0) -> void:
	if velocity.length_squared() <= MIN_SPEED_SQUARED:
		return
	var direction := velocity.normalized()
	if absf(direction.dot(Vector3.UP)) >= NEAR_VERTICAL:
		return
	_bank_into_turn(direction, delta)
	look_at(global_position + direction, Vector3.UP)
	rotate_object_local(Vector3.FORWARD, _bank)


func _bank_into_turn(direction: Vector3, delta: float) -> void:
	if delta > 0.0 and _heading != Vector3.ZERO:
		var turn_rate := _flat(_heading).signed_angle_to(_flat(direction), Vector3.UP) / delta
		var limit := deg_to_rad(max_bank_deg)
		var wanted := clampf(atan(-turn_rate * speed / GRAVITY), -limit, limit)
		_bank = lerpf(_bank, wanted, clampf(bank_response * delta, 0.0, 1.0))
	_heading = direction


func _flat(direction: Vector3) -> Vector3:
	return Vector3(direction.x, 0.0, direction.z).normalized()


func _on_flight_created() -> void:
	pass


func _on_flight_step(_delta: float) -> void:
	pass


@abstract
func _desired_velocity(delta: float) -> Vector3
