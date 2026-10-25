extends AbstractWeatherEffect
class_name RadarClutterWeather

@export var radar: SearchRadar


func _apply(profile: WeatherProfile, strength: float, _delta: float) -> void:
	radar.clutter = profile.radar_clutter * strength
