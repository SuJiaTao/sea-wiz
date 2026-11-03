extends RefCounted
class_name FormationApproach

enum Leg { CRUISE, BREAK, DONE }

var _heading: Vector3
var _break_range: float
var _break_turn: float
var _break_left: float
var _leg: Leg = Leg.CRUISE


func _init(heading: Vector3, break_range: float, break_turn: float, break_time: float) -> void:
	_heading = Vector3(heading.x, 0.0, heading.z).normalized()
	_break_range = break_range
	_break_turn = break_turn
	_break_left = break_time


func heading() -> Vector3:
	return _heading


func steer(enemy: FlyingEnemy, desired: Vector3, delta: float) -> Vector3:
	if _leg == Leg.CRUISE:
		var offset := enemy.target_position - enemy.global_position
		if Vector2(offset.x, offset.z).length() > _break_range:
			return _heading * enemy.speed
		_leg = Leg.BREAK if not is_zero_approx(_break_turn) else Leg.DONE
	if _leg == Leg.BREAK:
		_break_left -= delta
		if _break_left > 0.0:
			return _heading.rotated(Vector3.UP, _break_turn) * enemy.speed
		_leg = Leg.DONE
	return desired
