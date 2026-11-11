extends HUDPanel
class_name CoolantHUD

const LABEL_LIFT := Vector2(0, 20)
const BAR_OFFSET := Vector2(62, -10)
const BAR_SIZE := Vector2(128, 12)
const STATUS_OFFSET := Vector2(198, 0)
const HINT_FONT: int = 11
const LABEL_FONT: int = 12
const MESSAGE_TIME: float = 1.6
const MESSAGE_HEIGHT: float = 0.38
const MESSAGE_FONT: int = 15

@export var coolant: EmergencyCoolant
@export var loadout: ShipLoadout

var _message_left: float = 0.0


func _ready() -> void:
	coolant.vented.connect(_on_vented)


func _update_hud(delta: float) -> void:
	_message_left = maxf(_message_left - delta, 0.0)


func _draw() -> void:
	if get_tree().paused:
		return
	var origin := SlotLayout.origin(size, loadout.row_for(coolant.fitting))
	var ready := coolant.cooldown_left <= 0.0
	var status := "READY" if ready else "%d S" % ceili(coolant.cooldown_left)
	var fill := 1.0 - coolant.cooldown_left / EmergencyCoolant.COOLDOWN
	_text(origin - LABEL_LIFT, "%s  COOLANT DUMP" % loadout.key_for(coolant.fitting), HINT_FONT, FAINT)
	_text(origin, "COOLANT", LABEL_FONT, DIM)
	_bar(origin + BAR_OFFSET, BAR_SIZE, fill, MAIN if ready else DIM)
	_text(origin + STATUS_OFFSET, status, LABEL_FONT, MAIN if ready else DIM)
	if _message_left > 0.0:
		_center(size.y * MESSAGE_HEIGHT, "COOLANT DUMP", MESSAGE_FONT, DIM)


func _on_vented() -> void:
	_message_left = MESSAGE_TIME
