extends AbstractWeatherEffect
class_name FogWeather

@export var environment: WorldEnvironment
@export var haze_colour := Color(0.22, 0.22, 0.22)
@export var full_haze_density: float = 0.0015
@export var max_sky_wash: float = 0.85
@export var star_material: ShaderMaterial

var _base_density: float = 0.0
var _base_colour: Color
var _base_sky_affect: float = 0.0


func _ready() -> void:
	environment.environment = environment.environment.duplicate()
	var settings := environment.environment
	_base_density = settings.fog_density
	_base_colour = settings.fog_light_color
	_base_sky_affect = settings.fog_sky_affect


func _apply(profile: WeatherProfile, strength: float, _delta: float) -> void:
	var settings := environment.environment
	var extra := profile.fog_density * strength
	var haze := clampf(extra / full_haze_density, 0.0, 1.0)
	settings.fog_density = _base_density + extra
	settings.fog_light_color = _base_colour.lerp(haze_colour, haze)
	settings.fog_sky_affect = lerpf(_base_sky_affect, max_sky_wash, haze)
	star_material.set_shader_parameter("visibility", 1.0 - haze)
