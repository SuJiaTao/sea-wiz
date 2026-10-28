extends SubViewportContainer
class_name ThermalView

const BASE_GAIN := 1.35
const SHAKE_GAIN := 0.05
const SHAKE_OFFSET := 0.0035
const BURST_GAIN_DROP := 0.45
const BURST_FLASH := 0.6
const FLASH_RECOVERY := 6.0
const GAIN_RECOVERY := 1.2

@export var turret: Turret

var polarity: float = 0.0

var _flash: float = 0.0
var _gain_dip: float = 0.0

@onready var _thermal: ShaderMaterial = material as ShaderMaterial


func _ready() -> void:
	resized.connect(_update_sensor_size)
	_update_sensor_size()


func heat_burst(strength: float = 1.0) -> void:
	_flash = maxf(_flash, strength * BURST_FLASH)
	_gain_dip = maxf(_gain_dip, strength)


func _process(delta: float) -> void:
	var shake := 0.0
	if is_instance_valid(turret):
		shake = turret.shake_total()
	_flash = maxf(_flash - FLASH_RECOVERY * delta, 0.0)
	_gain_dip = maxf(_gain_dip - GAIN_RECOVERY * delta, 0.0)
	_thermal.set_shader_parameter("shake_x", randf_range(-shake, shake) * SHAKE_OFFSET)
	_thermal.set_shader_parameter("shake_y", randf_range(-shake, shake) * SHAKE_OFFSET)
	_thermal.set_shader_parameter("polarity", polarity)
	_thermal.set_shader_parameter("flash", _flash)
	_thermal.set_shader_parameter(
		"gain", (BASE_GAIN + shake * SHAKE_GAIN) * (1.0 - BURST_GAIN_DROP * _gain_dip)
	)


func _update_sensor_size() -> void:
	var sensor_size := size / float(stretch_shrink)
	_thermal.set_shader_parameter("sensor_size", sensor_size.max(Vector2(64, 36)))
