extends Node
class_name GunDirector

@export var turret: Turret


func lead_point(enemy: AbstractEnemy) -> Vector3:
	var muzzle := turret.muzzle.global_position
	var time := Ballistics.intercept_time(
		enemy.global_position - muzzle, enemy.velocity, Turret.MUZZLE_VELOCITY
	)
	if time <= 0.0:
		return enemy.global_position
	return Ballistics.aim_point(enemy.global_position, enemy.velocity, time)
