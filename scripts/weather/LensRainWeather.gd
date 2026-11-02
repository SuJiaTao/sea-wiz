extends AbstractWeatherEffect
class_name LensRainWeather

@export var lens: LensSpray

var _drops := EmissionRate.new()


func _apply(profile: WeatherProfile, strength: float, delta: float) -> void:
	for index in _drops.due(profile.lens_drops_per_second * strength, delta):
		lens.add_droplet()
