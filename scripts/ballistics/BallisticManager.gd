extends Node
class_name BallisticManager

const MAX_PROJECTILES: int = 4096

var _projectiles: Array[AbstractProjectile] = []
var _clearing: bool = false
var _exiting: bool = false


func fire(projectile: AbstractProjectile) -> bool:
	if projectile == null or _clearing or _exiting:
		return false
	if projectile._state != AbstractProjectile.State.FIRING:
		return false
	if _projectiles.size() >= MAX_PROJECTILES:
		return false
	if projectile.renderer != null:
		if not is_instance_valid(projectile.renderer):
			return false
		if not projectile.renderer.can_register():
			return false

	projectile._state = AbstractProjectile.State.FLYING
	_projectiles.append(projectile)
	projectile._on_fire()
	return true


func active_count() -> int:
	return _projectiles.size()


func clear_all() -> void:
	if _clearing:
		return
	_clearing = true
	var snapshot: Array[AbstractProjectile] = _projectiles.duplicate()
	for projectile in snapshot:
		_delete_projectile(projectile)
	_clearing = false


func _exit_tree() -> void:
	_exiting = true
	clear_all()


func _physics_process(delta: float) -> void:
	var targets := get_tree().get_nodes_in_group("enemy")
	var snapshot: Array[AbstractProjectile] = _projectiles.duplicate()
	for projectile in snapshot:
		if projectile._state == AbstractProjectile.State.FLYING:
			_propel_projectile(projectile, delta, targets)


func _should_delete_projectile(projectile: AbstractProjectile) -> bool:
	return (projectile._should_destroy) or ((projectile.max_lifetime - projectile.age) <= 0.0)

func _propel_projectile(
	projectile: AbstractProjectile,
	delta: float,
	targets: Array[Node]
) -> void:
	
	if projectile._state != AbstractProjectile.State.FLYING:
		return

	if _should_delete_projectile(projectile):
		_delete_projectile(projectile)
		return

	var pre_propel_pos := projectile.position

	projectile.age += delta
	projectile._requested_impact = null
	projectile._on_propel(delta)

	var post_propel_pos := projectile.position

	var impact := projectile._requested_impact if (projectile._requested_impact != null) else _sweep_impacts(projectile, pre_propel_pos, post_propel_pos, targets)

	if impact != null:
		projectile.position = impact.position
		_delete_projectile(projectile, impact)
		return


func _sweep_impacts(
	projectile: AbstractProjectile,
	start: Vector3,
	end: Vector3,
	targets: Array[Node]
) -> ProjectileImpact:

	var best: ProjectileImpact

	for node in targets:
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		var enemy := node as Enemy
		if enemy == null or not enemy.alive:
			continue
		var impact := enemy.sweep_sphere(start, end, projectile.radius)
		if impact != null and (best == null or impact.fraction < best.fraction):
			best = impact

	return best


func _delete_projectile(
	projectile: AbstractProjectile,
	impact: ProjectileImpact = null
) -> void:
	if projectile._state != AbstractProjectile.State.FLYING:
		return

	projectile._state = AbstractProjectile.State.IMPACTING
	_projectiles.erase(projectile)

	if impact != null:
		projectile._on_impact(impact)

	projectile._on_delete()
	projectile._state = AbstractProjectile.State.DELETED

