extends Node
class_name RadarSpinner

# Turns the surface search radar bar on the mast, round and round.

const BAR_NAME := "Radar_Spinner"
const SECONDS_PER_TURN: float = 2.5

@export var ship: Node3D

var _bar: Node3D


func _process(delta: float) -> void:
	if _bar == null:
		_bar = ship.find_child(BAR_NAME, true, false) as Node3D
		if _bar == null:
			return
	_bar.rotate_object_local(Vector3.UP, TAU / SECONDS_PER_TURN * delta)
