extends AbstractWeatherEffect
class_name CloudWeather

const CONTRAST := "cloud_contrast"

@export var environment: WorldEnvironment

var _clear_contrast: float = 0.0


func _ready() -> void:
	_clear_contrast = _sky().get_shader_parameter(CONTRAST)


func _apply(profile: WeatherProfile, strength: float, _delta: float) -> void:
	_sky().set_shader_parameter(CONTRAST, lerpf(_clear_contrast, profile.cloud_cover, strength))


func _sky() -> ShaderMaterial:
	return environment.environment.sky.sky_material as ShaderMaterial
