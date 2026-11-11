extends Node
class_name ShipRocking

const SETTLE_RATE: float = 1.2

@export var vessel: Node3D
@export var sway: ShipSway

var _rest: Transform3D
var _list := Vector3.ZERO
var _shown := Vector3.ZERO


func _ready() -> void:
	_rest = vessel.transform


## roll and pitch in degrees, dip in metres.
func take_list(roll_deg: float, pitch_deg: float, dip: float) -> void:
	_list = Vector3(roll_deg, pitch_deg, dip)


func _process(delta: float) -> void:
	_shown = _shown.move_toward(_list, SETTLE_RATE * delta * maxf(_list.length(), 1.0))
	var listing := Basis(Vector3.BACK, deg_to_rad(_shown.x)) * Basis(Vector3.RIGHT, deg_to_rad(_shown.y))
	vessel.transform = Transform3D(listing * sway.basis(), Vector3.DOWN * _shown.z) * _rest
