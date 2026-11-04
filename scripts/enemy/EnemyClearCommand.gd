extends RefCounted
class_name EnemyClearCommand

const COMMAND_NAME: StringName = &"clear_enemies"

var _enemies: EnemyManager


func _init(enemies: EnemyManager) -> void:
	_enemies = enemies
	DevConsole.register_command(COMMAND_NAME, _execute)


func _execute(_args: Array[String]) -> void:
	var count := _enemies.active_count()
	_enemies.clear_all()
	DevConsole.print_to_console("Cleared %d enemies" % count)
