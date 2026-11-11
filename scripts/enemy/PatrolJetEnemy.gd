extends JetEnemy
class_name PatrolJetEnemy

enum Patrol { ORBIT, SHADOW, EXIT, ENGAGED }

const PATROL_GROUP := &"patrol_flight"
const ANGULAR_SPEED: float = 0.09
const ORBIT_TIME: float = 18.0
const SHADOW_TIME: float = 12.0
const SHADOW_RADIUS_SHARE: float = 0.3
const SHADOW_ALTITUDE_SHARE: float = 0.5
const EXIT_CLIMB: float = 0.1
const EXIT_RANGE: float = 3800.0

var _patrol: Patrol = Patrol.ORBIT
var _patrol_clock: float = 0.0
var _orbit_radius: float = 0.0
var _orbit_altitude: float = 0.0
var _attack_speed: float = 0.0


func go_hostile() -> void:
	if _patrol == Patrol.ENGAGED:
		return
	_patrol = Patrol.ENGAGED
	speed = _attack_speed


func _on_flight_created() -> void:
	super._on_flight_created()
	add_to_group(PATROL_GROUP)
	_attack_speed = speed
	var offset := global_position - target_position
	_orbit_radius = Vector2(offset.x, offset.z).length()
	_orbit_altitude = global_position.y
	speed = ANGULAR_SPEED * _orbit_radius


func _on_damage(_amount: float, _world_point: Vector3) -> void:
	get_tree().call_group(PATROL_GROUP, "go_hostile")


func _on_flight_step(delta: float) -> void:
	_patrol_clock += delta
	if _patrol == Patrol.ORBIT and _patrol_clock >= ORBIT_TIME:
		_patrol = Patrol.SHADOW
	elif _patrol == Patrol.SHADOW and _patrol_clock >= ORBIT_TIME + SHADOW_TIME:
		_patrol = Patrol.EXIT
		speed = _attack_speed
	if _patrol == Patrol.EXIT and _flat_range() >= EXIT_RANGE:
		request_destroy()


func _desired_velocity(delta: float) -> Vector3:
	match _patrol:
		Patrol.ENGAGED:
			return super._desired_velocity(delta)
		Patrol.EXIT:
			return (_outward() + Vector3.UP * EXIT_CLIMB).normalized() * speed
		Patrol.SHADOW:
			return _circle(_orbit_radius * SHADOW_RADIUS_SHARE, _orbit_altitude * SHADOW_ALTITUDE_SHARE)
	return _circle(_orbit_radius, _orbit_altitude)


func _circle(radius: float, altitude: float) -> Vector3:
	return OrbitSteering.direction(global_position, target_position, radius, altitude) * speed


func _outward() -> Vector3:
	return _flat(global_position - target_position)


func _flat_range() -> float:
	var offset := global_position - target_position
	return Vector2(offset.x, offset.z).length()
