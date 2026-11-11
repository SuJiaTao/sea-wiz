extends HUDPanel
class_name CutoutHUD

const LABEL := "CUT-OUT"
const LABEL_DROP: float = 46.0
const LABEL_FONT: int = 14
const BLINK_RATE: float = 8.0
const BLINK_FLOOR: float = 0.6
const BLINK_DEPTH: float = 0.4

@export var turret: Turret

var _phase: float = 0.0


func _update_hud(delta: float) -> void:
	_phase += delta


func _draw() -> void:
	if not turret.cut_out or get_tree().paused:
		return
	var colour := DIM
	if turret.firing:
		colour = Color(MAIN, MAIN.a * (BLINK_FLOOR + BLINK_DEPTH * sin(_phase * BLINK_RATE)))
	_center(size.y * 0.5 + LABEL_DROP, LABEL, LABEL_FONT, colour)
