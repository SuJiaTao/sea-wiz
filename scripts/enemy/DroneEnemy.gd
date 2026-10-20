extends AbstractEnemy
class_name DroneEnemy

@export var speed: float = 85.0
@export_range(0.0, 1.0) var agility: float = 0.45
@export var target_position := Vector3.ZERO
@export var arrival_radius: float = 55.0

@onready var _hurtbox: Area3D = $Hurtbox

var _age: float = 0.0
var _weave_phase: float = 0.0


func _create() -> void:
	_weave_phase = randf() * TAU
	if velocity.length_squared() <= 0.000001:
		velocity = (target_position - global_position).normalized() * speed
	else:
		velocity = velocity.normalized() * speed
	_hurtbox.collision_mask = 0
	_hurtbox.monitoring = false
	_hurtbox.collision_layer = COLLISION_LAYER
	_face_velocity()


func _on_think(delta: float) -> void:
	var offset := target_position - global_position
	var flat_distance := Vector2(offset.x, offset.z).length()
	if flat_distance < arrival_radius or global_position.y < 2.0:
		request_destroy()
		return

	_age += delta
	var direction := offset.normalized()
	var side := direction.cross(Vector3.UP).normalized()
	var up := side.cross(direction).normalized()
	var amplitude := 0.9 * agility
	var desired := (
		direction
		+ side * sin(_age * 1.9 + _weave_phase) * amplitude
		+ up * sin(_age * 1.3 + _weave_phase * 1.7) * amplitude * 0.6
	).normalized() * speed
	var turn := lerpf(0.5, 5.0, agility) * delta
	velocity = velocity.lerp(desired, clampf(turn, 0.0, 1.0))
	if velocity.length_squared() > 0.000001:
		velocity = velocity.normalized() * speed
	global_position += velocity * delta
	_face_velocity()


func _face_velocity() -> void:
	if velocity.length_squared() <= 0.000001:
		return
	var direction := velocity.normalized()
	if absf(direction.dot(Vector3.UP)) < 0.985:
		look_at(global_position + direction, Vector3.UP)


func _on_destroy() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.collision_layer = 0
