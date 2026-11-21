extends RefCounted
class_name RadarTrack

const CONFIRM_HITS := 2
const MIN_UPDATE_INTERVAL := 0.01
const TENTATIVE_GROWTH := 150.0
const CONFIRMED_GROWTH := 35.0
const COAST_LIMIT := 1.2
const MAX_SPEED := 600.0
const MANEUVER_SHARE := 0.35
## Contacts at least this big on the scope are drawn as heavy (ships, motherships).
const HEAVY_RADIUS := 30.0

enum Kind { MISSILE, AIRCRAFT, HEAVY }

var id: int
var position: Vector3
var velocity := Vector3.ZERO
var uncertainty: float
var kind: Kind
var source: AbstractEnemy
var hits: int = 1
var since_update: float = 0.0

var confirmed: bool:
	get:
		return hits >= CONFIRM_HITS


func _init(track_id: int, detection: RadarDetection) -> void:
	id = track_id
	position = detection.position
	uncertainty = detection.error
	source = detection.source
	kind = _kind_of(detection.source)


static func _kind_of(enemy: AbstractEnemy) -> Kind:
	if enemy.contact_kind == AbstractEnemy.ContactKind.MISSILE:
		return Kind.MISSILE
	if enemy is SurfaceShipEnemy or enemy.hud_radius >= HEAVY_RADIUS:
		return Kind.HEAVY
	return Kind.AIRCRAFT


func follows(enemy: AbstractEnemy) -> bool:
	return is_instance_valid(source) and source == enemy


func lost() -> bool:
	return not is_instance_valid(source) or not source.alive


func predicted(after: float) -> Vector3:
	return position + velocity * after


func coast(delta: float) -> void:
	if since_update < COAST_LIMIT:
		position += velocity * delta
	since_update += delta
	# Fast contacts can stray further from where we expect them between sweeps.
	var growth := CONFIRMED_GROWTH if confirmed else TENTATIVE_GROWTH
	uncertainty += (growth + velocity.length() * MANEUVER_SHARE) * delta


func correct(measured: Vector3, error: float, alpha: float, beta: float) -> void:
	var interval := maxf(since_update, MIN_UPDATE_INTERVAL)
	var residual := measured - position
	if hits == 1:
		velocity = residual / interval
	else:
		velocity += residual * (beta / interval)
	velocity = velocity.limit_length(MAX_SPEED)
	position += residual * alpha
	# A big miss means the contact turned or sped up: widen the track to suit
	# instead of claiming a precision it no longer has.
	uncertainty = lerpf(uncertainty, maxf(error, residual.length()), alpha)
	hits += 1
	since_update = 0.0
