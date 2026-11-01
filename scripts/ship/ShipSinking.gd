extends Node
class_name ShipSinking

signal sunk

@export var integrity: ShipIntegrity
@export var vessel: Node3D
@export var gun: Node3D
@export var sea: Node3D
@export var max_depth: float = 12.0
@export var max_roll_deg: float = 12.0
@export var max_bow_down_deg: float = 3.5
@export var settle_rate: float = 0.35
@export var sinking_curve: float = 1.6
@export var gun_clearance: float = 0.5

var _shown_flooding: float = 0.0
var _rest: Transform3D
var _sunk: bool = false


func _ready() -> void:
	_rest = vessel.transform


func _process(delta: float) -> void:
	_shown_flooding = move_toward(_shown_flooding, integrity.flooding, settle_rate * delta)
	var sink := pow(_shown_flooding, sinking_curve)
	var tilt := (
		Basis(Vector3.BACK, deg_to_rad(max_roll_deg) * sink)
		* Basis(Vector3.RIGHT, -deg_to_rad(max_bow_down_deg) * sink)
	)
	vessel.transform = Transform3D(tilt, Vector3.DOWN * max_depth * sink) * _rest
	if not _sunk and gun.global_position.y <= sea.global_position.y + gun_clearance:
		_sunk = true
		sunk.emit()
