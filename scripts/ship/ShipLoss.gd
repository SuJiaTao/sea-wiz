extends Node
class_name ShipLoss

signal lost

enum Stage { AFLOAT, BURNING, EXPLODED, LOST }

const BURN_TIME: float = 2.6
const BLAST_TO_DARK: float = 0.3
const BLAST_SIZE: float = 6.0
const BLAST_SHAKE: float = 9.0
const BLAST_GLARE: float = 0.35
const AFTERSHOCK_SIZE: float = 3.5
const AFTERSHOCK_OFFSET := Vector3(4.0, -2.0, 3.0)
const LIST_ROLL_DEG: float = 3.5
const LIST_PITCH_DEG: float = 1.5
const LIST_DIP: float = 0.8
const KICK_ROLL_DEG: float = 6.0
const KICK_PITCH_DEG: float = 3.0

@export var integrity: ShipIntegrity
@export var fires: DeckFires
@export var bridge: Node3D
@export var rocking: ShipRocking
@export var sway: ShipSway
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
	var at := bridge.global_position
	effects.spawn(CloseBlastEffect.new(at, BLAST_SIZE))
	effects.spawn(CloseBlastEffect.new(at + AFTERSHOCK_OFFSET, AFTERSHOCK_SIZE))
	var side := signf(at.x - turret.global_position.x)
	if side == 0.0:
		side = 1.0
	rocking.take_list(LIST_ROLL_DEG * side, LIST_PITCH_DEG, LIST_DIP)
	sway.kick(KICK_ROLL_DEG * side, KICK_PITCH_DEG)
	turret.apply_camera_shake_impulse(BLAST_SHAKE)
	thermal.heat_burst(BLAST_GLARE)
