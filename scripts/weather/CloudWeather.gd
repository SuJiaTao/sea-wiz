extends AbstractWeatherEffect
class_name CloudWeather

const CONTRAST := "cloud_contrast"
const BUILD_RATE: float = 0.025

@export var environment: WorldEnvironment

var _clear_contrast: float = 0.0
var _build: float = 0.0
var _gathering_cover: float = 0.0


func _ready() -> void:
	_clear_contrast = _sky().get_shader_parameter(CONTRAST)


func _apply(profile: WeatherProfile, strength: float, delta: float) -> void:
	var forecast := (get_parent() as WeatherDirector).forecast
	_build = move_toward(_build, 1.0 if forecast != null else 0.0, BUILD_RATE * delta)
	var current := lerpf(_clear_contrast, profile.cloud_cover, strength)
	if forecast != null:
		_gathering_cover = forecast.cloud_cover
	var gathering := lerpf(_clear_contrast, _gathering_cover, _build)
	_sky().set_shader_parameter(CONTRAST, maxf(current, gathering))


func _sky() -> ShaderMaterial:
	return environment.environment.sky.sky_material as ShaderMaterial
