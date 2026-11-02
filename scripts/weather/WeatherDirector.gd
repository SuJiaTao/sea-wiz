extends Node
class_name WeatherDirector

signal changed(profile: WeatherProfile)

@export var waves: WaveOrchestrator
@export var clear: WeatherProfile
@export var fronts: Array[WeatherProfile] = []
@export var first_weather_level: int = 2
@export_range(0.0, 1.0) var front_chance: float = 0.6
@export var front_waves := Vector2i(2, 3)
@export var clear_waves := Vector2i(1, 2)
@export var transition_rate: float = 0.12

var profile: WeatherProfile
var strength: float = 0.0

var _front: WeatherFront
var _clear_left: int = 0
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


func start_front(front_profile: WeatherProfile, wave_count: int) -> void:
	_front = WeatherFront.new(front_profile, wave_count)
	_advance_front()


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
	if number < first_weather_level or fronts.is_empty():
		_settle(clear, 0.0)
	elif _front != null and _front.waves_left > 0:
		_advance_front()
	elif _clear_left > 0:
		_clear_left -= 1
		_settle(clear, 0.0)
	elif randf() < front_chance:
		start_front(_pick_front(), randi_range(front_waves.x, front_waves.y))
	else:
		_clear_left = randi_range(clear_waves.x, clear_waves.y) - 1
		_settle(clear, 0.0)


func _advance_front() -> void:
	_settle(_front.profile, _front.next_strength())
	if _front.waves_left <= 0:
		_clear_left = randi_range(clear_waves.x, clear_waves.y)


func _settle(next: WeatherProfile, next_strength: float) -> void:
	_target = next
	_target_strength = next_strength


func _pick_front() -> WeatherProfile:
	var choices := fronts.filter(func(candidate: WeatherProfile) -> bool: return candidate != profile)
	return (choices if not choices.is_empty() else fronts).pick_random()
