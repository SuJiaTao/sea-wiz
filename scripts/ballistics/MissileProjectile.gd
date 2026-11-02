extends AbstractProjectile
class_name MissileProjectile

signal detonated(position: Vector3, radius: float)

const LAUNCH_SPEED: float = 34.0
const BOOST_DELAY: float = 0.28
const CRUISE_SPEED: float = 265.0
const ACCELERATION: float = 420.0
const TURN_RATE: float = 4.6
const TURN_RATE_TERMINAL: float = 8.5
const TERMINAL_RANGE: float = 260.0
const GRAVITY: float = 9.81
const FUZE_RADIUS: float = 16.0
const CLOSEST_APPROACH_RANGE: float = 75.0
const BLAST_RADIUS: float = 26.0
const WARHEAD: float = 260.0
const WATER_SPLASH_SIZE: float = 1.2
const THREAT_RANGE: float = 650.0

var _target: AbstractEnemy
var _ballistics: BallisticManager
var _smoke: MissileSmokeRenderer
var _speed: float = LAUNCH_SPEED
var _last_distance: float = INF
var _decoy: DecoyFlare
var _threat_announced: bool = false


func _init(
	batch: ProjectileBatch,
	smoke: MissileSmokeRenderer,
	ballistics: BallisticManager,
	origin: Vector3,
	direction: Vector3,
	target: AbstractEnemy
) -> void:
	super(origin, direction.normalized() * LAUNCH_SPEED, 0.16, batch)
	_smoke = smoke
	_ballistics = ballistics
	_target = target
	max_lifetime = 14.0


func _on_propel(delta: float) -> void:
	if is_instance_valid(_target):
		if (
			not _target.alive
			or _target.hp <= 0.0
			or _target.is_queued_for_deletion()
			or _target._destroy_requested
		):
			_target = null
	else:
		_target = null
	_announce_threat()

	var previous := position
	if age < BOOST_DELAY:
		velocity.y -= GRAVITY * delta
	else:
		_speed = minf(_speed + ACCELERATION * delta, CRUISE_SPEED)
		if _target != null:
			var distance := position.distance_to(_target.global_position)
			var time_to_go := distance / maxf(_speed, 1.0)
			var aim := (
				_target.global_position
				+ _target.velocity * time_to_go * 0.9
			)
			_steer(aim, delta)
		elif _decoy != null and _decoy.burning:
			_steer(_decoy.position, delta)
		else:
			velocity = velocity.normalized() * _speed
			velocity.y -= GRAVITY * delta

	position += velocity * delta
	if is_instance_valid(_smoke):
		_smoke.emit_trail(previous, position, age < BOOST_DELAY)

	_check_fuze()
	_check_decoy()


func _announce_threat() -> void:
	if _target == null or _threat_announced:
		return
	if position.distance_to(_target.global_position) > THREAT_RANGE:
		return
	_threat_announced = true
	_decoy = _target.evade_missile(position)
	if _decoy != null:
		_target = null


func _check_decoy() -> void:
	if _decoy == null or not _decoy.burning:
		return
	if position.distance_to(_decoy.position) <= FUZE_RADIUS:
		_decoy = null
		request_impact(ProjectileImpact.new(position))


func _check_fuze() -> void:
	if _target == null:
		_last_distance = INF
		return

	for contact in _ballistics.sphere_contacts(
		position, CLOSEST_APPROACH_RANGE
	):
		if contact.managed_enemy != _target:
			continue
		var distance := position.distance_to(contact.point)
		if (
			distance <= FUZE_RADIUS
			or (
				distance < CLOSEST_APPROACH_RANGE
				and distance > _last_distance
			)
		):
			request_impact(contact)
		_last_distance = distance
		return
	_last_distance = INF


func _steer(aim: Vector3, delta: float) -> void:
	var offset := aim - position
	if offset.length_squared() <= 0.0001:
		velocity = velocity.normalized() * _speed
		return

	var desired := offset.normalized()
	var current := Vector3.UP
	if velocity.length_squared() > 0.000001:
		current = velocity.normalized()

	var rate := TURN_RATE
	if offset.length() < TERMINAL_RANGE:
		rate = TURN_RATE_TERMINAL

	var angle := current.angle_to(desired)
	if angle > 0.0001:
		var axis := current.cross(desired)
		if axis.length_squared() <= 0.000001:
			axis = current.cross(Vector3.RIGHT)
			if axis.length_squared() <= 0.000001:
				axis = current.cross(Vector3.UP)
		current = current.rotated(
			axis.normalized(), minf(rate * delta, angle)
		)
	velocity = current * _speed


func _on_impact(_impact: ProjectileImpact) -> void:
	detonated.emit(position, BLAST_RADIUS)
	for contact in _ballistics.sphere_contacts(position, BLAST_RADIUS):
		var enemy := contact.managed_enemy
		if not is_instance_valid(enemy):
			continue
		var distance := position.distance_to(contact.point)
		var falloff := pow(
			clampf(1.0 - distance / BLAST_RADIUS, 0.0, 1.0),
			0.6
		)
		enemy.take_damage(WARHEAD * falloff, position, weapon_source)


func _splash_size() -> float:
	return WATER_SPLASH_SIZE


func _on_delete() -> void:
	super()
	_target = null
	_decoy = null
	_ballistics = null
	_smoke = null


func visual_transform() -> Transform3D:
	var result := super()
	result.basis *= Basis(Vector3.RIGHT, deg_to_rad(-90.0))
	return result


func visual_color() -> Color:
	var heat := 1.2 if age < BOOST_DELAY else 3.0
	return Color(heat, heat, heat * 0.92, 1.0)
