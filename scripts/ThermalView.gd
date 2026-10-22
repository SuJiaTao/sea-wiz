extends SubViewportContainer
class_name ThermalView

@export var turret: Turret
@export var afterimage: SubViewport

var polarity: float = 0.0

@onready var _thermal: ShaderMaterial = material as ShaderMaterial


func _ready() -> void:
	_thermal.set_shader_parameter("sensor_image", afterimage.get_texture())
	resized.connect(_update_sensor_size)
	_update_sensor_size()


func _process(_delta: float) -> void:
	var shake := 0.0
	if is_instance_valid(turret):
		shake = turret.shake_total()
	_thermal.set_shader_parameter("shake_x", randf_range(-shake, shake) * 0.0035)
	_thermal.set_shader_parameter("shake_y", randf_range(-shake, shake) * 0.0035)
	_thermal.set_shader_parameter("polarity", polarity)
	_thermal.set_shader_parameter("gain", 1.35 + shake * 0.05)


func _update_sensor_size() -> void:
	var sensor_size := size / float(stretch_shrink)
	_thermal.set_shader_parameter("sensor_size", sensor_size.max(Vector2(64, 36)))
