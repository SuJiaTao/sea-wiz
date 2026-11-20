extends Node
class_name MeteorShower

const INTERVAL := Vector2(12.0, 40.0)
const DURATION := Vector2(0.5, 1.1)
const ARC_DEG := Vector2(8.0, 20.0)
const ELEVATION_DEG := Vector2(20.0, 70.0)
const TAIL_SHARE: float = 0.35
const FALL_SHARE: float = 0.7
const PEAK_GLOW: float = 0.7

@export var environment: WorldEnvironment

var _wait: float = 0.0
var _progress: float = -1.0
var _duration: float = 1.0
var _start := Vector3.UP
var _end := Vector3.UP


func _ready() -> void:
	_wait = randf_range(INTERVAL.x, INTERVAL.y)


func _process(delta: float) -> void:
	var sky := environment.environment.sky.sky_material as ShaderMaterial
	if _progress < 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_launch()
		return
	_progress += delta / _duration
	if _progress >= 1.0:
		_progress = -1.0
		_wait = randf_range(INTERVAL.x, INTERVAL.y)
		sky.set_shader_parameter("meteor_glow", 0.0)
		return
	sky.set_shader_parameter("meteor_head", _start.slerp(_end, _progress))
	sky.set_shader_parameter("meteor_tail", _start.slerp(_end, maxf(_progress - TAIL_SHARE, 0.0)))
	sky.set_shader_parameter("meteor_glow", PEAK_GLOW * sin(PI * _progress))


func _launch() -> void:
	var bearing := randf() * TAU
	var elevation := deg_to_rad(randf_range(ELEVATION_DEG.x, ELEVATION_DEG.y))
	var arc := deg_to_rad(randf_range(ARC_DEG.x, ARC_DEG.y))
	var drift := arc * signf(randf() - 0.5)
	_start = _direction(bearing, elevation)
	_end = _direction(bearing + drift, elevation - arc * FALL_SHARE)
	_duration = randf_range(DURATION.x, DURATION.y)
	_progress = 0.0


func _direction(bearing: float, elevation: float) -> Vector3:
	return Vector3(sin(bearing) * cos(elevation), sin(elevation), -cos(bearing) * cos(elevation))
