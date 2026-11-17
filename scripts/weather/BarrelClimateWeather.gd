extends AbstractWeatherEffect
class_name BarrelClimateWeather

@export var barrel_heat: BarrelHeat


func _apply(profile: WeatherProfile, strength: float, _delta: float) -> void:
	barrel_heat.heat_scale = lerpf(1.0, profile.barrel_heat_scale, strength)
	barrel_heat.cold = profile.barrel_cold * strength
	barrel_heat.wet = profile.barrel_wet * strength
