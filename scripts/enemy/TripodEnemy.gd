extends AbstractEnemy
class_name TripodEnemy

const LEG_PHASE_STEP := TAU / 3.0
const BEAM_HALF_LENGTH := 0.5
const SHIP_AIM_HEIGHT := 8.0

@export var standing_height: float = 55.0
@export var rise_speed: float = 9.0
@export var walk_speed: float = 8.0
@export var stride_rate: float = 1.1
@export var stride_swing_deg: float = 14.0
@export var bob_depth: float = 1.5
@export var ray_range: float = 700.0
@export var ray_interval: float = 4.5
@export var ray_time: float = 0.7
@export var ray_damage: float = 6.0
@export var light_sweep_deg: float = 35.0
@export var light_sweep_rate: float = 0.6
@export var target_position := Vector3.ZERO
@export var legs: Array[Node3D] = []
@export var lights: Node3D
@export var beam: Node3D
@export var eye: Node3D

var _clock: float = 0.0
var _ray_cooldown: float = 0.0
var _ray_left: float = 0.0

@onready var _hurtbox: Area3D = $Hurtbox


func impact_point() -> Vector3:
	return target_position + Vector3.UP * SHIP_AIM_HEIGHT


func _create() -> void:
	_hurtbox.collision_layer = COLLISION_LAYER
	global_position.y = -standing_height
	_ray_cooldown = ray_interval
	beam.visible = false


func _on_think(delta: float) -> void:
	_clock += delta
	_face_target()
	_sweep_lights()
	if global_position.y < 0.0:
		_rise(delta)
		return
	var offset := target_position - global_position
	var distance := Vector2(offset.x, offset.z).length()
	if distance > ray_range:
		_walk(delta, offset)
	else:
		velocity = Vector3.ZERO
		_fire_ray(delta)


func _rise(delta: float) -> void:
	velocity = Vector3.UP * rise_speed
	global_position.y = minf(global_position.y + rise_speed * delta, 0.0)


func _walk(delta: float, offset: Vector3) -> void:
	var heading := Vector3(offset.x, 0.0, offset.z).normalized()
	velocity = heading * walk_speed
	global_position += velocity * delta
	global_position.y = absf(sin(_clock * stride_rate)) * bob_depth
	for index in legs.size():
		legs[index].rotation.x = deg_to_rad(stride_swing_deg) * sin(_clock * stride_rate + index * LEG_PHASE_STEP)


func _fire_ray(delta: float) -> void:
	if _ray_left > 0.0:
		_ray_left -= delta
		_aim_beam()
		if _ray_left <= 0.0:
			beam.visible = false
		return
	_ray_cooldown -= delta
	if _ray_cooldown > 0.0:
		return
	_ray_cooldown = ray_interval
	_ray_left = ray_time
	beam.visible = true
	_aim_beam()
	reached_target.emit(ray_damage)


func _aim_beam() -> void:
	var from := eye.global_position
	var to := impact_point()
	beam.global_position = from.lerp(to, BEAM_HALF_LENGTH)
	beam.look_at(to, Vector3.UP)
	beam.scale = Vector3(1.0, 1.0, from.distance_to(to))


func _face_target() -> void:
	var flat := Vector3(target_position.x, global_position.y, target_position.z)
	if flat.distance_squared_to(global_position) > 1.0:
		look_at(flat, Vector3.UP)


func _sweep_lights() -> void:
	lights.rotation.y = deg_to_rad(light_sweep_deg) * sin(_clock * light_sweep_rate)


func _on_destroy() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.collision_layer = 0
