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


## Calls print_warning if an error occurs parsing string. [br]
## Saves [line] to [command_history].
static func parse_string_and_execute(line: String) -> void:
	command_history.push_back(line)
	if line.is_empty():
		print_warning_to_console("Please input a command.")
		return
	var argv = line.split(" ", false)
	# for i in len(argv):
	# 	argv[i] = argv[i].lstrip(" ")
	# 	argv[i] = argv[i].rstrip(" ")
	var arg0 = argv[0]
	print(_command_dict.keys())
	if not _command_dict.has(arg0):
		print_warning_to_console("Invalid command. Type 'list' to view all available commands.")
		return
	var args = argv.slice(1)
	_command_dict.get(arg0).call(args)


## Prints [msg] to console_ui. Also calls [ConsoleUI.print_message(msg)].
static func print_to_console(msg: String) -> void:
	console_ui.print_message(msg)


## Prints [msg] to console_ui Also, calls [ConsoleUI.print_warning(msg)].
static func print_warning_to_console(msg: String) -> void:
	console_ui.print_warning(msg)


static func get_command_list() -> Array[StringName]:
	return _command_dict.keys()


static func clear_all_history() -> void:
	command_history.clear()
	message_history.clear()


static func _static_init() -> void:
	load_default_commands()


static func load_default_commands() -> void:
	register_command("list", print_command_list)


static func print_command_list(_args) -> void:
	for key in get_command_list():
		console_ui.indent()
		console_ui.print_message(key)
