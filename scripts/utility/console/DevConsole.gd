extends Node
class_name DevConsole

static var _command_dict : Dictionary[StringName, Callable]

static var command_history : Array[String]
static var message_history : Array[String]
static var console_ui : ConsoleUI


## Registers a command to [DevConsole]. [br]
## Given function must be in the format:
## [codeblock]
##     func my_func(args: Array[String]):
## [/codeblock]
## Other parameters may be added after [args]
static func register_command(command: StringName, function: Callable) -> void:
	if _command_dict.has(command):
		push_warning("DevConsole has already registerd command " + command)
	_command_dict.set(command, function)


## Calls print_warning if an error occurs. [br]
## If successful, saves to command_history.
static func parse_string_and_execute(line: String) -> void:
	pass


## Prints [msg] to console_ui. Also, calls [ConsoleUI.print_message(msg)].
static func print_to_console(msg: String) -> void:
	pass


## Prints [msg] to console_ui. Also, calls [ConsoleUI.print_warning(msg)].
static func print_warning_to_console(msg: String) -> void:
	pass
