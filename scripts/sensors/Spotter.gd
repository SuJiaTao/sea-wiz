extends Node
class_name Spotter

signal marked(enemy: AbstractEnemy)

@export var turret: Turret
@export var enemies: EnemyManager
@export var spot_cone_deg: float = 2.5
@export var spot_time: float = 0.35
@export var max_spotting_fov: float = 32.0

var candidate: AbstractEnemy
var progress: float = 0.0

var _marked: Array[AbstractEnemy] = []


func is_marked(enemy: AbstractEnemy) -> bool:
	return _marked.has(enemy)


func marked_enemies() -> Array[AbstractEnemy]:
	var live: Array[AbstractEnemy] = []
	for enemy: Variant in _marked:
		if is_instance_valid(enemy) and enemy.alive:
			live.append(enemy)
	_marked = live
	return _marked


func _physics_process(delta: float) -> void:
	if turret.camera.fov > max_spotting_fov:
		_reset()
		return
	if not is_instance_valid(candidate):
		candidate = null
	var nearest := _unmarked_near_bore()
	if nearest == null:
		_reset()
		return
	if nearest != candidate:
		candidate = nearest
		progress = 0.0
	progress += delta / spot_time
	if progress >= 1.0:
		_marked.append(candidate)
		marked.emit(candidate)
		_reset()


func _reset() -> void:
	candidate = null
	progress = 0.0


func _unmarked_near_bore() -> AbstractEnemy:
	var eye := turret.camera.global_position
	var forward := -turret.camera.global_basis.z
	var best: AbstractEnemy
	var best_angle := spot_cone_deg
	for enemy in enemies.live_enemies():
		if _marked.has(enemy):
			continue
		var direction := (enemy.global_position - eye).normalized()
		var angle := rad_to_deg(forward.angle_to(direction))
		if angle < best_angle:
			best = enemy
			best_angle = angle
	return best
