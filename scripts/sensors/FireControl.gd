extends Node
class_name FireControl

signal locked_on(enemy: AbstractEnemy)

const LOCK_CONE_DEG: float = 4.0
const HOLD_CONE_DEG: float = 9.0

@export var turret: Turret
@export var spotter: Spotter
@export var gun_director: GunDirector

var locked: AbstractEnemy


func lock_range() -> float:
	return turret.camera.global_position.distance_to(locked.global_position)


func is_locked() -> bool:
	return is_instance_valid(locked) and locked.alive


func _physics_process(_delta: float) -> void:
	if is_locked() and _off_sight(locked) <= HOLD_CONE_DEG:
		return
	var best: AbstractEnemy
	var best_angle := LOCK_CONE_DEG
	for enemy in spotter.marked_enemies():
		var angle := _off_sight(enemy)
		if angle < best_angle:
			best = enemy
			best_angle = angle
	if best != locked:
		locked = best
		if best != null:
			locked_on.emit(best)


func _off_sight(enemy: AbstractEnemy) -> float:
	var eye := turret.camera.global_position
	var sight := -turret.camera.global_basis.z
	var at_target := rad_to_deg(sight.angle_to(enemy.global_position - eye))
	var at_lead := rad_to_deg(sight.angle_to(gun_director.lead_point(enemy) - eye))
	return minf(at_target, at_lead)
