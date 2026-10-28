extends AbstractWeatherEffect
class_name SeaStateWeather

const ROUGHNESS := "roughness"

@export var sea_material: ShaderMaterial
@export var sway: ShipSway


func _apply(profile: WeatherProfile, strength: float, _delta: float) -> void:
	sea_material.set_shader_parameter(ROUGHNESS, profile.sea_roughness * strength)
	sway.roll_deg = profile.ship_roll_deg * strength
