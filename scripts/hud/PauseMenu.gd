extends HUDPanel
class_name PauseMenu

# The pause menu, in the same framed panel as the resupply manifest: pick a
# line with its number key, or press escape to go back to the fight.

signal resume_requested()
signal restart_requested()
signal quit_requested()

const TITLE := "PAUSED"
const HINT := "PRESS 1 / 2 / 3"
const CHOICES: Array[Array] = [
	["RESUME", "Back to the fight."],
	["RESTART", "Start again from the sunset."],
	["QUIT", "Close the game."],
]
const PICK_ACTIONS: Array[StringName] = [&"supply_pick_1", &"supply_pick_2", &"supply_pick_3"]
const SELECT_TONE: AudioStream = preload("res://audio/supply/supply_select.wav")
const PANEL_WIDTH: float = 520.0
const PANEL_TOP: float = 0.36
const TITLE_HEIGHT: float = 34.0
const ROW_HEIGHT: float = 50.0
const PADDING := Vector2(18, 26)
const DESCRIPTION_DROP: float = 18.0
const HINT_INSET: float = 110.0
const TITLE_FONT: int = 14
const LABEL_FONT: int = 15
const DESCRIPTION_FONT: int = 11
const BACKING := Color(0.0, 0.05, 0.0, 0.55)

var _tone: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tone = AudioStreamPlayer.new()
	_tone.stream = SELECT_TONE
	_tone.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_tone)
	hide()


func open() -> void:
	show()


func close() -> void:
	hide()


func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	for index in PICK_ACTIONS.size():
		if event.is_action_pressed(PICK_ACTIONS[index]):
			_tone.play()
			_choose(index)
			return true
	return false


func _choose(index: int) -> void:
	match index:
		0:
			resume_requested.emit()
		1:
			restart_requested.emit()
		_:
			quit_requested.emit()


func _draw() -> void:
	if not visible:
		return
	var height := TITLE_HEIGHT + ROW_HEIGHT * CHOICES.size() + PADDING.y
	var panel := Rect2(Vector2((size.x - PANEL_WIDTH) * 0.5, size.y * PANEL_TOP), Vector2(PANEL_WIDTH, height))
	draw_rect(panel, BACKING)
	draw_rect(panel, DIM, false)
	var origin := panel.position + PADDING
	_text(origin, TITLE, TITLE_FONT)
	_text(origin + Vector2(PANEL_WIDTH - HINT_INSET - PADDING.x, 0), HINT, DESCRIPTION_FONT, FAINT)
	for index in CHOICES.size():
		var row := origin + Vector2(0, TITLE_HEIGHT + ROW_HEIGHT * index)
		_text(row, "%d   %s" % [index + 1, CHOICES[index][0]], LABEL_FONT)
		_text(row + Vector2(0, DESCRIPTION_DROP), CHOICES[index][1], DESCRIPTION_FONT, DIM)
