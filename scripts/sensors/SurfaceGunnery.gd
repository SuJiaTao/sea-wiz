extends Node
class_name SurfaceGunnery

# Put the sight on an enemy ship and it becomes the deck guns' target. The guns
# keep firing at it on their own until it sinks or the sight picks another.

@export var turret: Turret
@export var enemies: EnemyManager
@export var designate_cone_deg: float = 4.0

var target: SurfaceShipEnemy


func has_target() -> bool:
	return is_instance_valid(target) and target.alive


func _physics_process(_delta: float) -> void:
	if not has_target():
		target = null
	var sighted := _ship_in_sight()
	if sighted != null:
		target = sighted


func _ship_in_sight() -> SurfaceShipEnemy:
	var eye := turret.camera.global_position
	var forward := -turret.camera.global_basis.z
	var best: SurfaceShipEnemy
	var best_angle := designate_cone_deg
	for enemy in enemies.live_enemies():
		var ship := enemy as SurfaceShipEnemy
		if ship == null:
			continue
		var angle := rad_to_deg(forward.angle_to(ship.global_position - eye))
		if angle < best_angle:
			best = ship
			best_angle = angle
	return best
