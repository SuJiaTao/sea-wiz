extends Node
class_name WeatherDirector

# Weather follows the stages: each wave has its own weather in the schedule
# (the clear profile, or no entry, means clear skies). Clouds gather during
# the wave before weather arrives.

signal changed(profile: WeatherProfile)

@export var waves: WaveOrchestrator
@export var clear: WeatherProfile
@export var schedule: Array[WeatherProfile] = []
@export var transition_rate: float = 0.12

var profile: WeatherProfile
var strength: float = 0.0
var forecast: WeatherProfile

var _target: WeatherProfile
var _target_strength: float = 0.0
var _effects: Array[AbstractWeatherEffect] = []


func _ready() -> void:
	profile = clear
	_target = clear
	for child in get_children():
		if child is AbstractWeatherEffect:
			_effects.append(child)
	waves.level_prepared.connect(_on_level_prepared)


func _process(delta: float) -> void:
	if _target != profile:
		strength = move_toward(strength, 0.0, transition_rate * delta)
		if strength <= 0.0:
			profile = _target
			changed.emit(profile)
	else:
		strength = move_toward(strength, _target_strength, transition_rate * delta)
	for effect in _effects:
		effect._apply(profile, strength, delta)


func _on_level_prepared(number: int, _title: String) -> void:
	var now := _weather_for(number)
	var next := _weather_for(number + 1)
	_target = now if now != null else clear
	_target_strength = 1.0 if now != null else 0.0
	forecast = next if now == null and next != null else null


func _weather_for(number: int) -> WeatherProfile:
	if number < 1 or number > schedule.size() or schedule[number - 1] == clear:
		return null
	return schedule[number - 1]
