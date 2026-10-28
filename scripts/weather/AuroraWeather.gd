extends AbstractWeatherEffect
class_name AuroraWeather

const AURORA := "aurora"

@export var environment: WorldEnvironment


func _apply(profile: WeatherProfile, strength: float, _delta: float) -> void:
	var sky := environment.environment.sky.sky_material as ShaderMaterial
	sky.set_shader_parameter(AURORA, profile.aurora * strength)
