extends Control
class_name ConsoleUI

@export var text_field : LineEdit
@export var text_box : TextBox

var active : bool = false
var history_pointer : int = 0


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
	if event.is_action_pressed("ui_text_caret_up"):
		get_last_command()
	if event.is_action_pressed("ui_text_caret_down"):
		get_next_command()
	if event.is_action_pressed("ui_text_indent"):
		auto_complete_command()


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
	history_pointer = 0
	if line.is_empty():
		return
	text_field.clear()
	print_message(">" + line)
	DevConsole.parse_string_and_execute(line)


func get_last_command() -> void:
	var history = DevConsole.command_history
	if not active or history.is_empty():
		return
	var last = history[history_pointer]
	text_field.text = last
	text_field.set_caret_column.call_deferred(text_field.text.length())
	if history_pointer != history.size() - 1:
		history_pointer += 1


func get_next_command() -> void:
	var history = DevConsole.command_history
	if not active or history.is_empty():
		return
	if history_pointer == 0:
		return
	history_pointer -= 1
	var last = history[history_pointer]
	text_field.text = last
	text_field.set_caret_column.call_deferred(text_field.text.length())


func auto_complete_command() -> void:
	if not active:
		return
	var line : String = text_field.text
	if line.is_empty():
		return
	var result : String = line
	var commands = DevConsole.get_command_list()
	commands.sort_custom(func(s0, s1): return s0.length() < s1.length())
	for c in commands:
		if c.begins_with(line):
			if c != result:
				result = c
				break

	text_field.text = result
	text_field.set_caret_column.call_deferred(text_field.text.length())
	