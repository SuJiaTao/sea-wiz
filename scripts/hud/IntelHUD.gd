extends HUDPanel
class_name IntelHUD

const ADOPTED_PREFIX := "INTEL: ENEMY ADAPTED  /  "
const DROPPED_PREFIX := "INTEL: ENEMY DROPPED  /  "
const MESSAGE_TIME: float = 4.0
const MESSAGE_HEIGHT: float = 0.24
const MESSAGE_FONT: int = 14
const LIST_OFFSET := Vector2(-290, 210)
const LIST_FONT: int = 11
const LIST_TITLE := "ENEMY ADAPTATIONS"

@export var doctrine: EnemyDoctrine

var _message: String = ""
var _message_left: float = 0.0


func _ready() -> void:
	doctrine.warned.connect(func(counter: EnemyCounter) -> void: _show(counter.warning))
	doctrine.adopted.connect(func(counter: EnemyCounter) -> void: _show(ADOPTED_PREFIX + counter.tag))
	doctrine.dropped.connect(func(counter: EnemyCounter) -> void: _show(DROPPED_PREFIX + counter.tag))


func _update_hud(delta: float) -> void:
	_message_left = maxf(_message_left - delta, 0.0)


func _draw() -> void:
	if get_tree().paused:
		return
	if _message_left > 0.0:
		_center(size.y * MESSAGE_HEIGHT, _message, MESSAGE_FONT, DIM)
	if doctrine.active.is_empty():
		return
	var origin := Vector2(size.x, 0) + LIST_OFFSET
	_text(origin, LIST_TITLE, LIST_FONT, FAINT)
	for index in doctrine.active.size():
		_text(origin + Vector2(0, (index + 1) * (LIST_FONT + 4)), doctrine.active[index].tag, LIST_FONT, DIM)


func _show(message: String) -> void:
	_message = message
	_message_left = MESSAGE_TIME
