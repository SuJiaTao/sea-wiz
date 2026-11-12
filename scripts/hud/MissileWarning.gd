extends AudioStreamPlayer
class_name MissileWarning

# Radar warning beeps for an inbound missile: slow at long range, faster as
# the nearest missile closes on the ship, like a jet's warning receiver.

const FAR_RANGE: float = 4000.0
const NEAR_RANGE: float = 400.0
const SLOWEST_GAP: float = 0.55
const FASTEST_GAP: float = 0.07

@export var enemies: EnemyManager
@export var ship: Node3D

var _clock: float = 0.0
var _warning: bool = false


func _process(delta: float) -> void:
	var nearest := _nearest_inbound()
	if nearest == INF:
		_warning = false
		return
	var closeness := clampf((nearest - NEAR_RANGE) / (FAR_RANGE - NEAR_RANGE), 0.0, 1.0)
	var gap := lerpf(FASTEST_GAP, SLOWEST_GAP, closeness)
	_clock += delta
	if not _warning or _clock >= gap:
		_warning = true
		_clock = 0.0
		play()


func _nearest_inbound() -> float:
	var nearest := INF
	var at := ship.global_position
	for enemy in enemies.live_enemies():
		if enemy.contact_kind != AbstractEnemy.ContactKind.MISSILE or not enemy.alive:
			continue
		var toward := at - enemy.global_position
		if enemy.velocity.dot(toward) <= 0.0:
			continue
		nearest = minf(nearest, toward.length())
	return nearest
