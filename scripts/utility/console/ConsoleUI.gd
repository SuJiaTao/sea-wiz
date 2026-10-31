extends Node
class_name ConsoleUI


func _ready() -> void:
	DevConsole.console_ui = self


func print_message(msg: String) -> void:
	pass


func print_warning(msg: String) -> void:
	pass