extends Node
class_name EnemyDoctrine

signal warned(counter: EnemyCounter)
signal adopted(counter: EnemyCounter)
signal dropped(counter: EnemyCounter)

const ADAPT_WAVES := Vector2i(1, 3)

@export var counters: Array[EnemyCounter] = []
@export var loadout: ShipLoadout
@export var enemies: EnemyManager

var active: Array[EnemyCounter] = []

var _waves_until: Dictionary[EnemyCounter, int] = {}


func _ready() -> void:
	enemies.enemy_created.connect(_on_enemy_created)


func reassess() -> void:
	for counter in counters:
		var provoked := counter.provoked_by(loadout)
		if active.has(counter):
			if not provoked:
				active.erase(counter)
				dropped.emit(counter)
			continue
		if not provoked:
			_waves_until.erase(counter)
		elif _waves_until.has(counter):
			_waves_until[counter] -= 1
			if _waves_until[counter] <= 0:
				_waves_until.erase(counter)
				active.append(counter)
				adopted.emit(counter)
		else:
			_waves_until[counter] = randi_range(ADAPT_WAVES.x, ADAPT_WAVES.y)
			warned.emit(counter)


func _on_enemy_created(enemy: AbstractEnemy) -> void:
	if not enemy.hostile:
		return
	enemy.countermeasures_enabled = false
	for counter in active:
		counter.apply_to(enemy)
