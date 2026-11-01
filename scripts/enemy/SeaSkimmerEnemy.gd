extends FlyingEnemy
class_name SeaSkimmerEnemy

const SIDE_FLIP_CHANCE: float = 0.5

@export var cruise_altitude: float = 12.0
@export_range(0.0, 1.0) var miss_chance: float = 0.3
@export var miss_distance := Vector2(70.0, 220.0)

var _missing: bool = false

@onready var _hurtbox: Area3D = $Hurtbox


func _on_flight_created() -> void:
	_hurtbox.collision_layer = COLLISION_LAYER
	if randf() < miss_chance:
		_aim_wide()


func _desired_velocity(_delta: float) -> Vector3:
	var offset := target_position - global_position
	var direction := Vector3(offset.x, 0.0, offset.z).normalized()
	direction.y = clampf(
		(target_position.y + cruise_altitude - global_position.y) * 0.02,
		-0.25, 0.25
	)
	return direction.normalized() * speed


func _on_arrival() -> void:
	if not _missing:
		super()
		return
	request_destroy()
	missed.emit(global_position)


func _aim_wide() -> void:
	_missing = true
	var side := _flat(target_position - global_position).cross(Vector3.UP)
	if randf() < SIDE_FLIP_CHANCE:
		side = -side
	target_position += side * randf_range(miss_distance.x, miss_distance.y)


func _on_destroy() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.collision_layer = 0
