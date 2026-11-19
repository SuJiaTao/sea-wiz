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
## A quick star flares hard as it breaks from the sky, enough to star the lens.
@export var flare_time: float = 0.0
@export var flare_brightness: float = 1.0
## How much brighter it swells as it closes in after breaking from the sky.
@export var closing_glow: float = 1.0

var _drift_total: float = 1.0
var _drift_left: float = 0.0
var _flare: float = 0.0
var _dive_from: float = 0.0

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
		if _dive_from <= 0.0:
			_dive_from = global_position.distance_to(target_position)
		if flare_time > 0.0:
			_flare = minf(_flare + delta / flare_time, 1.0)
	var warming := 1.0 - clampf(_drift_left / _drift_total, 0.0, 1.0)
	var shine := lerpf(glow_brightness.x, glow_brightness.y, warming)
	shine = lerpf(shine, flare_brightness, _flare)
	if _dive_from > 0.0:
		var closed := 1.0 - global_position.distance_to(target_position) / _dive_from
		shine *= lerpf(1.0, closing_glow, clampf(closed, 0.0, 1.0))
	glow.set_instance_shader_parameter("brightness", shine)


func _desired_velocity(_delta: float) -> Vector3:
	return (target_position - global_position).normalized() * speed


func _on_destroy() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.collision_layer = 0
