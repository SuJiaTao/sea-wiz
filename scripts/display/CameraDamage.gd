extends Node
class_name CameraDamage

const FIRST_SIGNS_AT := 0.25
const WORST_AT := 1.0
const MAX_DAMAGE := 0.7
const EASE_PER_SECOND := 0.8

@export var integrity: ShipIntegrity
@export var video: AnalogVideo

var _shown: float = 0.0


func _process(delta: float) -> void:
	var target := smoothstep(FIRST_SIGNS_AT, WORST_AT, integrity.flooding) * MAX_DAMAGE
	_shown = move_toward(_shown, target, EASE_PER_SECOND * delta)
	video.set_camera_damage(_shown)
