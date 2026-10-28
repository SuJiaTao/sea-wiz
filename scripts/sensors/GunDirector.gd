extends Node
class_name GunDirector

@export var turret: Turret
@export var enemies: EnemyManager
@export var spotter: Spotter
@export var walk_cone_deg: float = 5.0
@export var walk_in_time: float = 1.2
@export var marked_walk_in_time: float = 0.6
@export var max_correction_deg: float = 8.0
@export var relax_time: float = 0.4

var target: AbstractEnemy
var convergence: float = 0.0


func lead_point(enemy: AbstractEnemy) -> Vector3:
	var muzzle := turret.muzzle.global_position
	var time := Ballistics.intercept_time(
		enemy.global_position - muzzle, enemy.velocity, Turret.MUZZLE_VELOCITY
	)
	if time <= 0.0:
		return enemy.global_position
	return Ballistics.aim_point(enemy.global_position, enemy.velocity, time)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or not target.alive:
		target = null
	if not turret.firing:
		_relax(delta)
		return
	var nearest := _enemy_near_bore()
	if nearest != target:
		target = nearest
		convergence = 0.0
	if target == null:
		return
	var walk_time := marked_walk_in_time if spotter.is_marked(target) else walk_in_time
	convergence = minf(convergence + delta / walk_time, 1.0)
	_steer_toward(lead_point(target), deg_to_rad(max_correction_deg) * convergence * delta)


func _relax(delta: float) -> void:
	convergence = maxf(convergence - delta / relax_time, 0.0)
	if convergence <= 0.0:
		target = null


func _enemy_near_bore() -> AbstractEnemy:
	var best: AbstractEnemy
	var best_angle := walk_cone_deg
	for enemy in enemies.live_enemies():
		var angle := minf(_off_bore(enemy.global_position), _off_bore(lead_point(enemy)))
		if angle < best_angle:
			best = enemy
			best_angle = angle
	return best


func _off_bore(point: Vector3) -> float:
	var bore := -turret.muzzle.global_basis.z
	return rad_to_deg(bore.angle_to((point - turret.muzzle.global_position).normalized()))


func _steer_toward(point: Vector3, step: float) -> void:
	var bore := -turret.muzzle.global_basis.z
	var wanted := (point - turret.muzzle.global_position).normalized()
	var yaw_error := wrapf(_yaw(wanted) - _yaw(bore), -PI, PI)
	var pitch_error := asin(clampf(wanted.y, -1.0, 1.0)) - asin(clampf(bore.y, -1.0, 1.0))
	turret.aim(clampf(yaw_error, -step, step), clampf(pitch_error, -step, step))


func _yaw(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)
