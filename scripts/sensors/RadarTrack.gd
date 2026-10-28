extends RefCounted
class_name RadarTrack

const CONFIRM_HITS := 2
const MIN_UPDATE_INTERVAL := 0.01
const TENTATIVE_GROWTH := 300.0
const CONFIRMED_GROWTH := 35.0

var id: int
var position: Vector3
var velocity := Vector3.ZERO
var uncertainty: float
var size_hint: float
var signature: String = ""
var hits: int = 1
var since_update: float = 0.0

var confirmed: bool:
	get:
		return hits >= CONFIRM_HITS


func _init(track_id: int, detection: RadarDetection) -> void:
	id = track_id
	position = detection.position
	uncertainty = detection.error
	size_hint = detection.size_hint


func predicted(after: float) -> Vector3:
	return position + velocity * after


func coast(delta: float) -> void:
	position += velocity * delta
	since_update += delta
	uncertainty += (CONFIRMED_GROWTH if confirmed else TENTATIVE_GROWTH) * delta


func correct(measured: Vector3, error: float, alpha: float, beta: float) -> void:
	var interval := maxf(since_update, MIN_UPDATE_INTERVAL)
	var residual := measured - position
	if hits == 1:
		velocity = residual / interval
	else:
		velocity += residual * (beta / interval)
	position += residual * alpha
	uncertainty = lerpf(uncertainty, error, alpha)
	hits += 1
	since_update = 0.0
