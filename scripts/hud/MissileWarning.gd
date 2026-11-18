extends AudioStreamPlayer
class_name MissileWarning

# Radar warning beeps for an inbound missile: slow at long range, faster as
# the nearest missile closes on the ship, like a jet's warning receiver. The
# beeps come from the side the missile is on, relative to where the gun faces.

const FAR_RANGE: float = 4000.0
const NEAR_RANGE: float = 400.0
const SLOWEST_GAP: float = 0.55
const FASTEST_GAP: float = 0.07
const BUS_NAME := &"MissileWarning"
const OUTPUT_BUS := &"Master"
const PAN_REACH: float = 0.9

@export var enemies: EnemyManager
@export var ship: Node3D
@export var turret: Turret

var _clock: float = 0.0
var _warning: bool = false
var _panner: AudioEffectPanner


func _ready() -> void:
	var index := AudioServer.get_bus_index(BUS_NAME)
	if index < 0:
		index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, BUS_NAME)
		AudioServer.set_bus_send(index, OUTPUT_BUS)
		AudioServer.add_bus_effect(index, AudioEffectPanner.new())
	_panner = AudioServer.get_bus_effect(index, 0) as AudioEffectPanner
	bus = BUS_NAME


func _process(delta: float) -> void:
	var nearest := _nearest_inbound()
	if nearest == null:
		_warning = false
		return
	var distance := ship.global_position.distance_to(nearest.global_position)
	var closeness := clampf((distance - NEAR_RANGE) / (FAR_RANGE - NEAR_RANGE), 0.0, 1.0)
	var gap := lerpf(FASTEST_GAP, SLOWEST_GAP, closeness)
	_clock += delta
	if not _warning or _clock >= gap:
		_warning = true
		_clock = 0.0
		_panner.pan = _side_of(nearest.global_position)
		play()


## -1 fully left, 1 fully right, as heard facing the way the gun points.
func _side_of(point: Vector3) -> float:
	var camera := turret.camera
	var toward := point - camera.global_position
	toward.y = 0.0
	var right := camera.global_basis.x
	right.y = 0.0
	if toward.length_squared() == 0.0 or right.length_squared() == 0.0:
		return 0.0
	return toward.normalized().dot(right.normalized()) * PAN_REACH


func _nearest_inbound() -> AbstractEnemy:
	var nearest: AbstractEnemy = null
	var best := INF
	var at := ship.global_position
	for enemy in enemies.live_enemies():
		if enemy.contact_kind != AbstractEnemy.ContactKind.MISSILE or not enemy.alive:
			continue
		var toward := at - enemy.global_position
		if enemy.velocity.dot(toward) <= 0.0:
			continue
		if toward.length() < best:
			best = toward.length()
			nearest = enemy
	return nearest
