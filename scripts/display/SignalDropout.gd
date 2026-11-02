extends Node
class_name SignalDropout

const DAMAGE_FOR_FULL_DROPOUT := 25.0
const PEAK := 0.8
const RECOVERY_PER_SECOND := 2.5

@export var integrity: ShipIntegrity
@export var video: AnalogVideo

var _amount: float = 0.0


func _ready() -> void:
	integrity.damaged.connect(_on_damaged)


func _process(delta: float) -> void:
	if _amount <= 0.0:
		return
	_amount = maxf(_amount - RECOVERY_PER_SECOND * delta, 0.0)
	video.set_dropout(_amount)


func _on_damaged(amount: float, _from_position: Vector3) -> void:
	_amount = minf(_amount + amount / DAMAGE_FOR_FULL_DROPOUT, PEAK)
