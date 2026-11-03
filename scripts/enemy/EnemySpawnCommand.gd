extends RefCounted
class_name EnemySpawnCommand

const COMMAND_NAME: StringName = &"spawn"
const CATALOG: EnemyCatalog = preload("res://resources/enemies/EnemyCatalog.tres")
const MAX_COUNT: int = 50
const DISTANCE := Vector2(700.0, 1000.0)
const ALTITUDE := Vector2(100.0, 200.0)

var _enemies: EnemyManager


func _init(enemies: EnemyManager) -> void:
	_enemies = enemies
	DevConsole.register_command(COMMAND_NAME, _execute)


func _execute(args: Array[String]) -> void:
	if args.is_empty():
		DevConsole.print_warning_to_console(_usage())
		return
	var scene := CATALOG.find(args[0])
	if scene == null:
		DevConsole.print_warning_to_console("Unknown enemy. " + _usage())
		return
	var count := clampi(args[1].to_int() if args.size() > 1 else 1, 1, MAX_COUNT)
	for i in count:
		_spawn(scene)
	DevConsole.print_to_console("Spawned %d x %s" % [count, args[0]])


func _spawn(scene: PackedScene) -> void:
	var enemy := scene.instantiate() as AbstractEnemy
	var angle := randf() * TAU
	var distance := randf_range(DISTANCE.x, DISTANCE.y)
	var altitude := randf_range(ALTITUDE.x, ALTITUDE.y)
	var offset := Vector3(cos(angle) * distance, altitude, sin(angle) * distance)
	var spawn_transform := Transform3D(Basis.IDENTITY, _enemies.global_position + offset)
	if not _enemies.create(enemy, spawn_transform):
		enemy.free()
		DevConsole.print_warning_to_console("EnemyManager rejected the spawn.")


func _usage() -> String:
	return "Usage: spawn <%s> [count]" % "|".join(CATALOG.names())
