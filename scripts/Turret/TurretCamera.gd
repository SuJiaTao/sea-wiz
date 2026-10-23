class_name TurretCamera
extends Camera3D

const FOV_WIDE := 55.0
const FOV_NARROW := 17.0

const SHAKE_DECAY := 7.0
const SHAKE_TO_OFFSET := 0.015
const SHAKE_CAP := 2.4
const IMPULSE_DECAY := 12.0
const IMPULSE_CAP := 6.0

var _shake: float = 0.0
var _impulse: float = 0.0

var _base_position : Vector3
var _zoom_level: float = 0.0

func _ready() -> void:
	_base_position = position

func _process(delta: float) -> void:
	_shake = lerpf(_shake, 0.0, clampf(delta * SHAKE_DECAY, 0.0, 1.0))
	_impulse = lerpf(_impulse, 0.0, clampf(delta * IMPULSE_DECAY, 0.0, 1.0))
	var amount: float = shake_total()
	h_offset = randf_range(-amount, amount) * SHAKE_TO_OFFSET
	v_offset = randf_range(-amount, amount) * SHAKE_TO_OFFSET

func _physics_process(delta: float) -> void:
	var zoom := maxf(
		_zoom_level,
		1.0 if Input.is_action_pressed("ciws_zoom") else 0.0
	)
	var desired_fov := lerpf(FOV_WIDE, FOV_NARROW, zoom)
	fov = lerpf(fov, desired_fov, clampf(delta * 8.0, 0.0, 1.0))

func nudge_zoom(amount: float) -> void:
	_zoom_level = clampf(_zoom_level + amount, 0.0, 1.0)

func apply_shake(strength: float) -> void:
	_shake = minf(_shake + strength, SHAKE_CAP)

func apply_shake_impulse(value: float) -> void:
	_impulse = minf(_impulse + value, IMPULSE_CAP)

func shake_total() -> float:
	return _shake + _impulse

func recoil(offset: Vector3) -> void:
	position = _base_position + offset