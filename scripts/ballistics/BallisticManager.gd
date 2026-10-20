extends Node
class_name BallisticManager

const MAX_PROJECTILES: int = 4096

var _projectiles: Array[AbstractProjectile] = []
var _clearing: bool = false
var _exiting: bool = false


func fire(projectile: AbstractProjectile) -> bool:
	if projectile == null or _clearing or _exiting:
		return false
	if projectile._state != AbstractProjectile.State.NEW:
		return false
	if _projectiles.size() >= MAX_PROJECTILES:
		return false
	if projectile.renderer != null:
		if not is_instance_valid(projectile.renderer):
			return false
		if not projectile.renderer.can_register():
			return false

	projectile._state = AbstractProjectile.State.ACTIVE
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
		_finish(projectile, AbstractProjectile.DeleteReason.CLEARED)
	_clearing = false


func _exit_tree() -> void:
	_exiting = true
	clear_all()


func _physics_process(delta: float) -> void:
	var targets := get_tree().get_nodes_in_group("enemy")
	var snapshot: Array[AbstractProjectile] = _projectiles.duplicate()
	for projectile in snapshot:
		if projectile._state == AbstractProjectile.State.ACTIVE:
			_step(projectile, delta, targets)


func _step(
	projectile: AbstractProjectile,
	delta: float,
	targets: Array[Node]
) -> void:
	if projectile._should_destroy:
		_finish(projectile, AbstractProjectile.DeleteReason.REQUESTED)
		return
	var remaining_life := projectile.max_lifetime - projectile.age
	if remaining_life <= 0.0:
		_finish(projectile, AbstractProjectile.DeleteReason.EXPIRED)
		return
	if projectile.distance_travelled >= projectile.max_distance:
		_finish(projectile, AbstractProjectile.DeleteReason.RANGE)
		return

	var step_delta := minf(delta, remaining_life)
	var previous := projectile.position
	projectile.age += step_delta
	projectile._requested_impact = null
	projectile._on_propel(step_delta)

	if projectile._state != AbstractProjectile.State.ACTIVE:
		return
	if projectile._should_destroy:
		_finish(projectile, AbstractProjectile.DeleteReason.REQUESTED)
		return

	var endpoint := projectile.position
	var step_distance := previous.distance_to(endpoint)
	var remaining_distance := projectile.max_distance - projectile.distance_travelled
	var reached_range := step_distance >= remaining_distance
	if reached_range and step_distance > 0.0:
		endpoint = previous.lerp(
			endpoint, clampf(remaining_distance / step_distance, 0.0, 1.0)
		)
		projectile.position = endpoint

	var impact := _first_impact(projectile, previous, endpoint, targets)
	if impact != null:
		projectile.position = impact.position
		projectile.distance_travelled += previous.distance_to(impact.position)
		var reason := AbstractProjectile.DeleteReason.IMPACT
		if impact.enemy == null:
			reason = AbstractProjectile.DeleteReason.GROUND
		_finish(projectile, reason, impact)
		return

	projectile.distance_travelled += previous.distance_to(endpoint)
	if not reached_range and projectile._requested_impact != null:
		_finish(
			projectile,
			AbstractProjectile.DeleteReason.IMPACT,
			projectile._requested_impact
		)
	elif reached_range:
		_finish(projectile, AbstractProjectile.DeleteReason.RANGE)
	elif projectile.age >= projectile.max_lifetime:
		_finish(projectile, AbstractProjectile.DeleteReason.EXPIRED)


func _first_impact(
	projectile: AbstractProjectile,
	start: Vector3,
	end: Vector3,
	targets: Array[Node]
) -> ProjectileImpact:
	var best: ProjectileImpact
	var floor_y := projectile.ground_height + projectile.radius
	if start.y <= floor_y or end.y <= floor_y:
		var fraction := 0.0
		if start.y > floor_y:
			fraction = (start.y - floor_y) / (start.y - end.y)
		best = ProjectileImpact.new(start.lerp(end, fraction))
		best.fraction = fraction
		best.point = best.position - Vector3.UP * projectile.radius

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


func _finish(
	projectile: AbstractProjectile,
	reason: AbstractProjectile.DeleteReason,
	impact: ProjectileImpact = null
) -> void:
	if projectile._state != AbstractProjectile.State.ACTIVE:
		return
	projectile._state = AbstractProjectile.State.TERMINATING
	_projectiles.erase(projectile)
	if impact != null:
		projectile._on_impact(impact)
	projectile._on_delete(reason)
	projectile._requested_impact = null
	projectile._state = AbstractProjectile.State.DELETED

