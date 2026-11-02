extends Node
class_name WaveOrchestrator

signal completed()
signal failed(reason: String)
signal level_prepared(number: int, title: String)
signal level_started(number: int, title: String)

enum State { STOPPED, INTERMISSION, SPAWNING, FINISHED }

@export var levels: Array[WaveDefinition] = []
@export var initial_delay: float = 3.0
@export var intermission: float = 7.0

var level_number: int = 0
var level_title: String = ""
var intermission_remaining: float = 0.0

var _state: State = State.STOPPED
var _enemies: EnemyManager
var _pending: Array[WaveSpawn] = []
var _clock: float = 0.0
var _group_bearings: Dictionary[StringName, float] = {}


func start(enemies: EnemyManager) -> void:
	if _state != State.STOPPED:
		return
	var error := _validate()
	if not error.is_empty():
		_fail(error)
		return
	if not is_instance_valid(enemies):
		_fail("WaveOrchestrator requires an EnemyManager.")
		return
	_enemies = enemies
	level_number = 0
	_begin_next_level()


func stop() -> void:
	_state = State.STOPPED
	_pending.clear()
	_enemies = null


func _physics_process(delta: float) -> void:
	if _state == State.INTERMISSION:
		intermission_remaining = maxf(intermission_remaining - delta, 0.0)
		if intermission_remaining <= 0.0:
			_state = State.SPAWNING
			level_started.emit(level_number, level_title)
		return
	if _state != State.SPAWNING:
		return
	_clock += delta
	while not _pending.is_empty() and _pending[0].time <= _clock:
		var entry: WaveSpawn = _pending.pop_front()
		if not _spawn(entry):
			return
	if _pending.is_empty() and _enemies.active_count() == 0:
		_begin_next_level()


func _begin_next_level() -> void:
	if level_number >= levels.size():
		_state = State.FINISHED
		completed.emit()
		return
	var definition := levels[level_number]
	level_number += 1
	level_title = definition.title
	_pending = definition.spawns.duplicate()
	_pending.sort_custom(_earlier)
	_group_bearings.clear()
	_clock = 0.0
	intermission_remaining = initial_delay if level_number == 1 else intermission
	_state = State.INTERMISSION
	level_prepared.emit(level_number, level_title)


func _spawn(entry: WaveSpawn) -> bool:
	var instance := entry.enemy_scene.instantiate()
	var enemy := instance as AbstractEnemy
	if enemy == null:
		instance.free()
		_fail("Wave scene root must extend AbstractEnemy.")
		return false
	var angle := _bearing_for(entry.group)
	var distance := randf_range(entry.distance.x, entry.distance.y)
	var altitude := randf_range(entry.altitude.x, entry.altitude.y)
	var position := _enemies.global_position + Vector3(
		cos(angle) * distance, altitude, sin(angle) * distance
	)
	if not _enemies.create(enemy, Transform3D(Basis.IDENTITY, position)):
		enemy.free()
		_fail("EnemyManager rejected a wave spawn.")
		return false
	return true


func _bearing_for(group: StringName) -> float:
	if group.is_empty():
		return randf() * TAU
	if not _group_bearings.has(group):
		_group_bearings[group] = randf() * TAU
	return _group_bearings[group]


func _validate() -> String:
	if levels.is_empty():
		return "No levels configured."
	for definition in levels:
		if definition == null or definition.spawns.is_empty():
			return "Each level must contain spawn entries."
		for entry in definition.spawns:
			if entry == null or entry.enemy_scene == null:
				return "Each spawn must specify an enemy scene."
			if entry.time < 0.0:
				return "Spawn times must be nonnegative."
			if entry.distance.x < 0.0 or entry.distance.y < entry.distance.x:
				return "Invalid spawn distance range."
			if entry.altitude.y < entry.altitude.x:
				return "Invalid spawn altitude range."
	return ""


func _fail(reason: String) -> void:
	stop()
	failed.emit(reason)


func _earlier(a: WaveSpawn, b: WaveSpawn) -> bool:
	return a.time < b.time
