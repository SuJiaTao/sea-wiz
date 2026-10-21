extends Node3D
class_name EnemyManager

signal enemy_created(enemy: AbstractEnemy)
signal enemy_killed(enemy: AbstractEnemy, weapon_source: Script)

var _enemies: Array[AbstractEnemy] = []
var _clearing: bool = false
var _exiting: bool = false


func create(
	enemy: AbstractEnemy,
	world_transform: Transform3D = Transform3D.IDENTITY
) -> bool:
	if not is_instance_valid(enemy) or _clearing or _exiting:
		return false
	if not is_inside_tree() or enemy.is_queued_for_deletion():
		return false
	if enemy._state != AbstractEnemy.State.CREATING:
		return false
	if enemy.get_parent() != null or enemy.max_hp <= 0.0:
		return false
	enemy.transform = global_transform.affine_inverse() * world_transform
	_enemies.append(enemy)
	add_child(enemy)
	if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
		enemy_created.emit(enemy)
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy._activate()
	if is_instance_valid(enemy) and enemy._destroy_requested:
		_destroy_enemy(enemy)
	return true


func active_count() -> int:
	return _enemies.size()


func live_enemies() -> Array[AbstractEnemy]:
	var result: Array[AbstractEnemy] = []
	for enemy in _enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.is_queued_for_deletion() or enemy._destroy_requested:
			continue
		if enemy.alive and enemy.hp > 0.0:
			result.append(enemy)
	return result


func clear_all() -> void:
	if _clearing:
		return
	_clearing = true
	var snapshot: Array[AbstractEnemy] = _enemies.duplicate()
	for enemy in snapshot:
		_destroy_enemy(enemy)
	_clearing = false


func _physics_process(delta: float) -> void:
	var snapshot: Array[AbstractEnemy] = _enemies.duplicate()
	for enemy in snapshot:
		if not is_instance_valid(enemy):
			_enemies.erase(enemy)
			continue
		if enemy.is_queued_for_deletion() or enemy._destroy_requested:
			_destroy_enemy(enemy)
			continue
		if not enemy.alive:
			continue
		if enemy.hp <= 0.0:
			enemy._state = AbstractEnemy.State.DEAD
			enemy._on_killed()
			enemy_killed.emit(enemy, enemy._killing_weapon_source)
			_destroy_enemy(enemy)
			continue

		enemy._on_think(delta)
		if is_instance_valid(enemy) and enemy._destroy_requested:
			_destroy_enemy(enemy)


func _destroy_enemy(enemy: AbstractEnemy) -> void:
	_enemies.erase(enemy)
	if not is_instance_valid(enemy):
		return
	enemy._destroy()
	if not enemy.is_queued_for_deletion():
		enemy.queue_free()


func _exit_tree() -> void:
	_exiting = true
	clear_all()
