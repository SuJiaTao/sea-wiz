extends Control
class_name ConsoleUI

@export var text_field : TextEdit
@export var text_box : TextBox


func _ready() -> void:
	DevConsole.console_ui = self
	hide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_console"):
		visible = not visible
		CursorManager.capture_mouse(not visible)


func print_message(msg: String) -> void:
	if text_box:
		text_box.push(msg)


func print_warning(msg: String) -> void:
	if text_box:
		text_box.push(wrap_color(msg, "yellow"))


func wrap_color(line: String, color: String) -> String:
	return "[color=" + color + "]" + line + "[/color]"