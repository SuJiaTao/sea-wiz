extends Node
class_name ShipLoss
## The end of the ship: fire takes every deck, the forward magazine goes up
## beside the mount, and the camera feed dies.

signal lost

enum Stage { AFLOAT, BURNING, EXPLODED, LOST }

const BURN_TIME: float = 2.6
const BLAST_TO_DARK: float = 0.8
const BLAST_SIZE: float = 9.0
const BLAST_SHAKE: float = 9.0

@export var integrity: ShipIntegrity
@export var fires: DeckFires
@export var effects: EffectManager
@export var turret: Turret
@export var thermal: ThermalView
@export var feed: SignalDropout

var _stage: Stage = Stage.AFLOAT
var _clock: float = 0.0


func _ready() -> void:
	integrity.damaged.connect(_on_damaged)


func _process(delta: float) -> void:
	if _stage == Stage.AFLOAT or _stage == Stage.LOST:
		return
	_clock += delta
	if _stage == Stage.BURNING and _clock >= BURN_TIME:
		_explode()
	elif _stage == Stage.EXPLODED and _clock >= BURN_TIME + BLAST_TO_DARK:
		_stage = Stage.LOST
		feed.cut()
		lost.emit()


func _on_damaged(_amount: float, _from_position: Vector3) -> void:
	if _stage == Stage.AFLOAT and integrity.flooding >= 1.0:
		_stage = Stage.BURNING
		fires.engulf()


func _explode() -> void:
	_stage = Stage.EXPLODED
	var at := fires.spot_nearest(turret.global_position)
	effects.spawn(BigExplosionEffect.new(at, BLAST_SIZE))
	turret.apply_camera_shake_impulse(BLAST_SHAKE)
	thermal.heat_burst()
