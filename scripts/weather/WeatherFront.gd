extends RefCounted
class_name WeatherFront

const BUILD_UP: Array[float] = [0.6, 1.0, 0.75]

var profile: WeatherProfile
var waves_left: int
var _wave_index: int = 0


func _init(front_profile: WeatherProfile, waves: int) -> void:
	profile = front_profile
	waves_left = waves


func next_strength() -> float:
	var strength := BUILD_UP[mini(_wave_index, BUILD_UP.size() - 1)]
	_wave_index += 1
	waves_left -= 1
	return strength
