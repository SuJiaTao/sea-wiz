extends Node
class_name HUDCorruption
## The head-up display breaks up as the ship takes damage: channels split
## and lines tear, worse with every hit, settling back as it is repaired.

const PARAMETER := "corruption"
const FIRST_SIGNS_AT := 0.2
const WORST_AT := 1.0
const HIT_SPIKE := 0.5
const SPIKE_RECOVERY := 2.5

@export var integrity: ShipIntegrity
@export var laser: LaserHUD

var _spike: float = 0.0


func _ready() -> void:
	integrity.damaged.connect(_on_damaged)


func _process(delta: float) -> void:
	var material := laser.glass_material()
	if material == null:
		return
	_spike = maxf(_spike - SPIKE_RECOVERY * delta, 0.0)
	var wear := smoothstep(FIRST_SIGNS_AT, WORST_AT, integrity.flooding)
	material.set_shader_parameter(PARAMETER, clampf(wear + _spike, 0.0, 1.0))


func _on_damaged(_amount: float, _from_position: Vector3) -> void:
	_spike = HIT_SPIKE
