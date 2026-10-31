extends Control
class_name ConsoleUI

@export var text_field : LineEdit
@export var text_box : TextBox

var active : bool = false


func _ready() -> void:
	DevConsole.console_ui = self
	DevConsole.register_command("clear", text_box.clear_text.unbind(1))
	hide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_console"):
		if active:
			set_inactive()
		else:
			set_active()
	if event.is_action_pressed("enter_text"):
		process_text()


func set_active() -> void:
	active = true
	visible = true
	text_field.grab_focus.call_deferred()
	CursorManager.free_mouse()


func set_inactive() -> void:
	active = false
	visible = false
	CursorManager.capture_mouse()


func print_message(msg: String) -> void:
	if text_box:
		text_box.push(msg)


func print_warning(msg: String) -> void:
	if text_box:
		text_box.push(wrap_color(msg, "yellow"))


func indent(count:int=1) -> void:
	text_box.indent(count)


func wrap_color(line: String, color: String) -> String:
	return "[color=" + color + "]" + line + "[/color]"


func process_text() -> void:
	if not active:
		return
	var line : String = text_field.text
	if line.is_empty():
		return
	text_field.clear()
	print_message(">" + line)
	DevConsole.parse_string_and_execute(line)