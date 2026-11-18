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


## Where the CIWS sight is looking: at the locked jet's range, or a default one.
func sight_point(default_range: float) -> Vector3:
	var camera := turret.camera
	var reach := lock_range() if is_locked() else default_range
	return camera.global_position - camera.global_basis.z * reach


func _physics_process(_delta: float) -> void:
	var best: AbstractEnemy
	var best_angle := LOCK_CONE_DEG
	if is_locked() and _off_sight(locked) <= HOLD_CONE_DEG:
		best = locked
		best_angle = minf(_off_sight(locked), LOCK_CONE_DEG)
	for enemy in spotter.marked_enemies():
		var angle := _off_sight(enemy)
		if enemy != locked and angle < best_angle:
			best = enemy
			best_angle = angle
	if best != locked:
		locked = best
		if best != null:
			locked_on.emit(best)


func _off_sight(enemy: AbstractEnemy) -> float:
	var eye := turret.camera.global_position
	var sight := -turret.camera.global_basis.z
	return rad_to_deg(sight.angle_to(enemy.global_position - eye))
