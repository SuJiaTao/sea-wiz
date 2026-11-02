extends RefCounted
class_name ComboChain

var multiplier: int = 1
var remaining: float = 0.0

var _window: float
var _max_multiplier: int


func _init(window: float, max_multiplier: int) -> void:
	_window = window
	_max_multiplier = max_multiplier


func extend() -> int:
	multiplier = mini(multiplier + 1, _max_multiplier) if remaining > 0.0 else 1
	remaining = _window
	return multiplier


func tick(delta: float) -> void:
	remaining = maxf(remaining - delta, 0.0)
	if remaining <= 0.0:
		multiplier = 1


func fraction_left() -> float:
	return remaining / _window
