extends AbstractWeatherEffect
class_name BloodMoonWeather

const MOON_COLOR := "moon_color"
const MOON_PHASE := "moon_phase_deg"
const MOON_GLOW := "moon_glow"
const FULL_MOON_PHASE := 180.0

@export var environment: WorldEnvironment
@export var blood_color := Color(0.95, 0.18, 0.12)
@export var glow_boost: float = 0.6

var _sky: ShaderMaterial
var _normal_color: Color
var _normal_phase: float
var _normal_glow: float


func _ready() -> void:
	_sky = environment.environment.sky.sky_material as ShaderMaterial
	_normal_color = _sky.get_shader_parameter(MOON_COLOR)
	_normal_phase = _sky.get_shader_parameter(MOON_PHASE)
	_normal_glow = _sky.get_shader_parameter(MOON_GLOW)


func _apply(profile: WeatherProfile, strength: float, _delta: float) -> void:
	var amount := profile.blood_moon * strength
	_sky.set_shader_parameter(MOON_COLOR, _normal_color.lerp(blood_color, amount))
	_sky.set_shader_parameter(MOON_PHASE, lerpf(_normal_phase, FULL_MOON_PHASE, amount))
	_sky.set_shader_parameter(MOON_GLOW, _normal_glow + glow_boost * amount)
