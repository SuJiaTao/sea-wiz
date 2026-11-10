extends HUDPanel
class_name DecoyHUD

const LABEL_LIFT := Vector2(0, 20)
const BAR_OFFSET := Vector2(62, -10)
const BAR_SIZE := Vector2(128, 12)
const STATUS_OFFSET := Vector2(198, 0)
const HINT_FONT: int = 11
const LABEL_FONT: int = 12
const ORIGIN_OFFSET := Vector2(28, -390)
const MESSAGE_TIME: float = 1.6
const MESSAGE_HEIGHT: float = 0.38
const MESSAGE_FONT: int = 15

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
	_text(origin - LABEL_LIFT, "X  CHAFF", HINT_FONT, FAINT)
	_text(origin, "DECOY", LABEL_FONT, DIM)
	_bar(origin + BAR_OFFSET, BAR_SIZE, fill, MAIN if loaded else DIM)
	_text(origin + STATUS_OFFSET, status, LABEL_FONT, MAIN if loaded else DIM)
	if _message_left > 0.0:
		_center(size.y * MESSAGE_HEIGHT, "CHAFF CHAFF", MESSAGE_FONT, DIM)


func _on_launched() -> void:
	_message_left = MESSAGE_TIME
