extends AbstractWeatherEffect
class_name CloudWeather

const CONTRAST := "cloud_contrast"
const BUILD_RATE: float = 0.025
const OVERCAST := "overcast"
const STAR_SHADE := "cloud_shade"
const FADE_RATE: float = 0.04

@export var environment: WorldEnvironment
@export var star_material: ShaderMaterial

var _clear_contrast: float = 0.0
var _build: float = 0.0
var _gathering_cover: float = 0.0
var _shown_contrast: float = 0.0
var _shown_overcast: float = 0.0


func _ready() -> void:
	_clear_contrast = _sky().get_shader_parameter(CONTRAST)
	_shown_contrast = _clear_contrast


func _apply(profile: WeatherProfile, strength: float, delta: float) -> void:
	var forecast := (get_parent() as WeatherDirector).forecast
	_build = move_toward(_build, 1.0 if forecast != null else 0.0, BUILD_RATE * delta)
	var current := lerpf(_clear_contrast, profile.cloud_cover, strength)
	if forecast != null:
		_gathering_cover = forecast.cloud_cover
	var gathering := lerpf(_clear_contrast, _gathering_cover, _build)
	_shown_contrast = move_toward(_shown_contrast, maxf(current, gathering), FADE_RATE * delta)
	_sky().set_shader_parameter(CONTRAST, _shown_contrast)
	var raining := strength if profile.cloud_cover > 0.0 else 0.0
	var overcast := maxf(raining, _build if _gathering_cover > 0.0 else 0.0)
	_shown_overcast = move_toward(_shown_overcast, overcast, FADE_RATE * delta)
	_sky().set_shader_parameter(OVERCAST, _shown_overcast)
	star_material.set_shader_parameter(STAR_SHADE, _shown_overcast)


func _sky() -> ShaderMaterial:
	return environment.environment.sky.sky_material as ShaderMaterial
