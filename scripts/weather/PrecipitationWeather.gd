extends AbstractWeatherEffect
class_name PrecipitationWeather

@export var rain: PrecipitationField
@export var snow: PrecipitationField


func _apply(profile: WeatherProfile, strength: float, _delta: float) -> void:
	rain.set_amount(profile.rain_rate * strength)
	snow.set_amount(profile.snow_rate * strength)
