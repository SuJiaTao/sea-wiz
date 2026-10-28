@abstract
extends FlyingEnemy
class_name StrikeAircraft

enum Leg { RUN_IN, EGRESS }

const MAX_DIVE_SLOPE: float = 0.3
const MAX_CLIMB_SLOPE: float = 0.4
const PULL_UP_SHARE: float = 0.6
const PULL_UP_SLOPE: float = 0.2

@export var attack_altitude: float = 90.0
@export var egress_distance: float = 1300.0
@export var egress_climb: float = 0.15

var _leg: Leg = Leg.RUN_IN
var _egress_heading := Vector3.FORWARD


func _on_arrival() -> void:
	if _leg != Leg.RUN_IN:
		return
	reached_target.emit(contact_damage)
	_leg = Leg.EGRESS
	_egress_heading = _flat(velocity)


func _desired_velocity(_delta: float) -> Vector3:
	if _leg == Leg.EGRESS:
		var away := global_position - target_position
		if Vector2(away.x, away.z).length() < egress_distance:
			return _hold_altitude(_egress_heading + Vector3.UP * egress_climb) * speed
		_leg = Leg.RUN_IN
	var aim := target_position + Vector3.UP * attack_altitude
	return _hold_altitude(aim - global_position) * speed


func _hold_altitude(direction: Vector3) -> Vector3:
	var flat := _flat(direction)
	var slope := direction.y / maxf(Vector2(direction.x, direction.z).length(), MIN_SPEED_SQUARED)
	slope = clampf(slope, -MAX_DIVE_SLOPE, MAX_CLIMB_SLOPE)
	if global_position.y - target_position.y < attack_altitude * PULL_UP_SHARE:
		slope = maxf(slope, PULL_UP_SLOPE)
	return (flat + Vector3.UP * slope).normalized()
