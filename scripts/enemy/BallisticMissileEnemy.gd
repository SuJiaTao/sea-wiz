extends FlyingEnemy
class_name BallisticMissileEnemy

const STAR_KILL_LABEL := "STAR KILL"

@export var drift_speed: float = 40.0
@export var dive_speed: float = 280.0
@export var dive_acceleration: float = 60.0
@export var drift_time := Vector2(7.0, 13.0)
@export var star_bonus: float = 2.5
@export var glow: GeometryInstance3D
@export var glow_brightness := Vector2(0.7, 1.0)

var _drift_total: float = 1.0
var _drift_left: float = 0.0

var looks_like_star: bool:
	get:
		return _drift_left > 0.0

@onready var _hurtbox: Area3D = $Hurtbox


func score_points() -> int:
	return roundi(score_value * star_bonus) if looks_like_star else score_value


func score_label() -> String:
	return STAR_KILL_LABEL if looks_like_star else display_name


func _on_flight_created() -> void:
	_hurtbox.collision_layer = COLLISION_LAYER
	_drift_total = randf_range(drift_time.x, drift_time.y)
	_drift_left = _drift_total
	speed = drift_speed


func _on_flight_step(delta: float) -> void:
	if looks_like_star:
		_drift_left -= delta
	else:
		speed = move_toward(speed, dive_speed, dive_acceleration * delta)
	var warming := 1.0 - clampf(_drift_left / _drift_total, 0.0, 1.0)
	glow.set_instance_shader_parameter("brightness", lerpf(glow_brightness.x, glow_brightness.y, warming))


func _desired_velocity(_delta: float) -> Vector3:
	return (target_position - global_position).normalized() * speed


func _on_destroy() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.collision_layer = 0
