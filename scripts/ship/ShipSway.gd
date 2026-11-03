extends Node
class_name ShipSway

@export var roll_period: float = 9.0
@export var pitch_period: float = 6.5
@export var pitch_share: float = 0.45
@export var pitch_phase: float = 1.3
@export_range(0.0, 1.0) var kick_damping: float = 0.2

var roll_deg: float = 0.0

var _clock: float = 0.0
var _kick := Vector2.ZERO
var _kick_rate := Vector2.ZERO


func kick(roll_rate_deg: float, pitch_rate_deg: float) -> void:
	_kick_rate += Vector2(deg_to_rad(roll_rate_deg), deg_to_rad(pitch_rate_deg))


func _process(delta: float) -> void:
	_clock += delta
	var stiffness := Vector2(pow(TAU / roll_period, 2.0), pow(TAU / pitch_period, 2.0))
	var damping := Vector2(TAU / roll_period, TAU / pitch_period) * 2.0 * kick_damping
	_kick_rate -= (_kick * stiffness + _kick_rate * damping) * delta
	_kick += _kick_rate * delta


func basis() -> Basis:
	var roll := deg_to_rad(roll_deg) * sin(TAU * _clock / roll_period)
	var pitch := deg_to_rad(roll_deg * pitch_share) * sin(TAU * _clock / pitch_period + pitch_phase)
	return Basis(Vector3.BACK, roll + _kick.x) * Basis(Vector3.RIGHT, pitch + _kick.y)
