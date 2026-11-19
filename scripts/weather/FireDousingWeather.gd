extends AbstractWeatherEffect
class_name FireDousingWeather

# Rain soaks the deck and the sea: fires on board die down and burning fuel on
# the water burns out sooner while it rains.

@export var effects: EffectManager


func _apply(profile: WeatherProfile, strength: float, _delta: float) -> void:
	effects.wetness = clampf(profile.rain_rate / SeaStateWeather.FULL_RAIN_RATE, 0.0, 1.0) * strength
