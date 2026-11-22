extends AbstractWeatherEffect
class_name SeaStateWeather

const ROUGHNESS := "roughness"
const RAIN := "rain"
const FULL_RAIN_RATE: float = 30000.0

@export var sea_material: ShaderMaterial
@export var sway: ShipSway


func _apply(profile: WeatherProfile, strength: float, _delta: float) -> void:
	sea_material.set_shader_parameter(ROUGHNESS, profile.sea_roughness * strength)
	sea_material.set_shader_parameter(RAIN, clampf(profile.rain_rate / FULL_RAIN_RATE, 0.0, 1.0) * strength)
	sway.roll_deg = profile.ship_roll_deg * strength
