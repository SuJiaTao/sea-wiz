extends HUDPanel
class_name DecoyHUD

const ORIGIN_OFFSET := Vector2(28, -390)
const MESSAGE_TIME: float = 1.6

@export var decoys: DecoyLauncher

var _message_left: float = 0.0


func _ready() -> void:
	decoys.launched.connect(_on_launched)


func _update_hud(delta: float) -> void:
	_message_left = maxf(_message_left - delta, 0.0)


func _draw() -> void:
	if get_tree().paused:
		return
	var origin := Vector2(0, size.y) + ORIGIN_OFFSET
	var loaded := decoys.cooldown_left <= 0.0
	var status := "READY" if loaded else "%d S" % ceili(decoys.cooldown_left)
	var fill := 1.0 - decoys.cooldown_left / DecoyLauncher.COOLDOWN
	_text(origin - Vector2(0, 20), "X  CHAFF", 11, FAINT)
	_text(origin, "DECOY", 12, DIM)
	_bar(origin + Vector2(62, -10), Vector2(128, 12), fill, MAIN if loaded else DIM)
	_text(origin + Vector2(198, 0), status, 12, MAIN if loaded else DIM)
	if _message_left > 0.0:
		_center(size.y * 0.38, "CHAFF CHAFF", 15, DIM)


func _on_launched() -> void:
	_message_left = MESSAGE_TIME
