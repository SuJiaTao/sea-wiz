extends Node
class_name ShipSway

@export var roll_period: float = 9.0
@export var pitch_period: float = 6.5
@export var pitch_share: float = 0.45
@export var pitch_phase: float = 1.3

var roll_deg: float = 0.0

var _clock: float = 0.0


func _process(delta: float) -> void:
	_clock += delta


func basis() -> Basis:
	var roll := deg_to_rad(roll_deg) * sin(TAU * _clock / roll_period)
	var pitch := deg_to_rad(roll_deg * pitch_share) * sin(TAU * _clock / pitch_period + pitch_phase)
	return Basis(Vector3.BACK, roll) * Basis(Vector3.RIGHT, pitch)
