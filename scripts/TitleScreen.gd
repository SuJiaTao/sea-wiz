extends Control
class_name TitleScreen

signal start_requested()

@onready var _prompt: Label = $Center/Content/Prompt

var _phase: float = 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_phase += delta
	_prompt.modulate.a = 0.45 + 0.45 * sin(_phase * 3.0)


func handle_input(event: InputEvent) -> bool:
	if not is_visible_in_tree():
		return false
	if (
		event.is_action_pressed("ciws_restart")
		or event.is_action_pressed("ciws_fire")
	):
		start_requested.emit()
		return true
	return false
