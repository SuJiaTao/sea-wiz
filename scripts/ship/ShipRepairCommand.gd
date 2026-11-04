extends RefCounted
class_name ShipRepairCommand

const COMMAND_NAME: StringName = &"repair"

var _integrity: ShipIntegrity


func _init(integrity: ShipIntegrity) -> void:
	_integrity = integrity
	DevConsole.register_command(COMMAND_NAME, _execute)


func _execute(args: Array[String]) -> void:
	var amount := args[0].to_float() if not args.is_empty() else _integrity.capacity
	_integrity.repair(amount)
	DevConsole.print_to_console("Hull damage: %.1f / %.1f" % [_integrity.damage, _integrity.capacity])
