@abstract
extends FlyingEnemy
class_name StrikeAircraft

enum Leg { RUN_IN, EGRESS }

const MAX_DIVE_SLOPE: float = 0.3
const MAX_CLIMB_SLOPE: float = 0.4
const PULL_UP_SHARE: float = 0.6
const PULL_UP_SLOPE: float = 0.2
const LAUNCH_DROP := Vector3(0.0, -3.0, 0.0)
const GUN_CONE_COS: float = 0.94

@export var attack_altitude: float = 90.0
@export var egress_distance: float = 1300.0
@export var egress_climb: float = 0.15
@export var missile_scene: PackedScene
@export var missiles_carried: int = 0
@export var launch_range: float = 2200.0
@export var launch_turn_deg: float = 130.0
@export var gun_range: float = 1000.0

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
	var range_left := global_position - target_position
	var flat_range := Vector2(range_left.x, range_left.z).length()
	if contact_damage > 0.0 and flat_range < gun_range and _pointed_at_target():
		_strafe()
	elif missiles_carried > 0 and flat_range >= gun_range and flat_range < launch_range:
		_launch_missile()
	var aim := target_position + Vector3.UP * attack_altitude
	return _hold_altitude(aim - global_position) * speed


func _pointed_at_target() -> bool:
	return velocity.normalized().dot((target_position - global_position).normalized()) > GUN_CONE_COS


func _strafe() -> void:
	var burst := GunBurst.new()
	burst.shooter = self
	burst.target = target_position
	get_parent().add_child(burst)
	reached_target.emit(contact_damage)
	_break_off()


func _break_off() -> void:
	_leg = Leg.EGRESS
	_egress_heading = _flat(velocity).rotated(Vector3.UP, deg_to_rad(launch_turn_deg) * signf(randf() - 0.5))


func _launch_missile() -> void:
	missiles_carried -= 1
	var missile := missile_scene.instantiate() as FlyingEnemy
	missile.velocity = velocity
	weapon_launched.emit(missile, Transform3D(Basis.IDENTITY, global_position + LAUNCH_DROP))
	_break_off()


func _hold_altitude(direction: Vector3) -> Vector3:
	var flat := _flat(direction)
	var slope := direction.y / maxf(Vector2(direction.x, direction.z).length(), MIN_SPEED_SQUARED)
	slope = clampf(slope, -MAX_DIVE_SLOPE, MAX_CLIMB_SLOPE)
	if global_position.y - target_position.y < attack_altitude * PULL_UP_SHARE:
		slope = maxf(slope, PULL_UP_SLOPE)
	return (flat + Vector3.UP * slope).normalized()
