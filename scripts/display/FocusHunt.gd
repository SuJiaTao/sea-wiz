extends Node
class_name FocusHunt

const ERROR_PER_DEGREE := 0.04
const MAX_ERROR := 0.45
const SETTLE_PER_SECOND := 1.6
const OVERSHOOT_RATE := 9.0

@export var turret: Turret
@export var thermal: ThermalView

var _error: float = 0.0
var _hunt_time: float = 0.0
var _last_fov: float = 0.0


func _ready() -> void:
	_last_fov = turret.camera.fov


func _process(delta: float) -> void:
	var fov := turret.camera.fov
	_error = minf(_error + absf(fov - _last_fov) * ERROR_PER_DEGREE, MAX_ERROR)
	_last_fov = fov
	_error = maxf(_error - SETTLE_PER_SECOND * delta, 0.0)
	_hunt_time += delta
	thermal.focus_error = _error * absf(cos(_hunt_time * OVERSHOOT_RATE))
