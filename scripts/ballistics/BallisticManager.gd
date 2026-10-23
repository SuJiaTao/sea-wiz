extends Node
class_name BallisticManager

const MAX_PROJECTILES: int = 4096
const MIN_CAST_RADIUS: float = 0.001

@export_flags_3d_physics var collision_mask: int = AbstractEnemy.COLLISION_LAYER

var _projectiles: Array[AbstractProjectile] = []
var _clearing: bool = false
var _exiting: bool = false
var _sphere_cast: ShapeCast3D
var _sphere: SphereShape3D


func _ready() -> void:
	_sphere = SphereShape3D.new()
	_sphere.radius = MIN_CAST_RADIUS
	_sphere_cast = ShapeCast3D.new()
	_sphere_cast.enabled = false
	_sphere_cast.exclude_parent = false
	_sphere_cast.collide_with_areas = true
	_sphere_cast.collide_with_bodies = true
	_sphere_cast.max_results = 1
	_sphere_cast.shape = _sphere
	add_child(_sphere_cast)


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
	var snapshot: Array[AbstractProjectile] = _projectiles.duplicate()
	for projectile in snapshot:
		if projectile._state == AbstractProjectile.State.FLYING:
			_propel_projectile(projectile, delta)


func _should_delete_projectile(projectile: AbstractProjectile) -> bool:
	return (projectile._should_destroy) or ((projectile.max_lifetime - projectile.age) <= 0.0)

func _propel_projectile(
	projectile: AbstractProjectile,
	delta: float
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

	var impact := projectile._requested_impact
	if impact == null:
		impact = _spherecast(pre_propel_pos, post_propel_pos, projectile.radius)

	if impact != null:
		projectile.position = impact.position
		if projectile._deflects(impact):
			projectile._on_deflect(impact)
			return
		_delete_projectile(projectile, impact)
		return


func _spherecast(
	start: Vector3,
	end: Vector3,
	radius: float
) -> ProjectileImpact:
	_sphere.radius = maxf(radius, MIN_CAST_RADIUS)
	_sphere_cast.global_transform = Transform3D(Basis.IDENTITY, start)
	_sphere_cast.target_position = end - start
	_sphere_cast.collision_mask = collision_mask
	_sphere_cast.force_shapecast_update()
	if not _sphere_cast.is_colliding():
		return null

	var fraction := _sphere_cast.get_closest_collision_unsafe_fraction()
	var impact := ProjectileImpact.new(start.lerp(end, fraction))
	
	impact.fraction = fraction
	impact.point = _sphere_cast.get_collision_point(0)
	impact.normal = _sphere_cast.get_collision_normal(0)
	impact.collider = _sphere_cast.get_collider(0)

	impact.managed_enemy = _enemy_from_collider(impact.collider)
	return impact


func sphere_contacts(
	center: Vector3,
	radius: float
) -> Array[ProjectileImpact]:
	var result: Array[ProjectileImpact] = []
	if radius <= 0.0 or not is_instance_valid(_sphere_cast):
		return result

	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.margin = 0.0

	var space := _sphere_cast.get_world_3d().direct_space_state
	var excluded: Array[RID] = []
	var contacts: Dictionary[AbstractEnemy, ProjectileImpact] = {}

	while true:
		var hit := space.get_rest_info(query)
		if hit.is_empty():
			break
		excluded.append(hit["rid"])
		query.exclude = excluded

		var collider := instance_from_id(int(hit["collider_id"]))
		var enemy := _enemy_from_collider(collider)
		if not is_instance_valid(enemy):
			continue
		if not enemy.alive or enemy.hp <= 0.0:
			continue
		if enemy.is_queued_for_deletion() or enemy._destroy_requested:
			continue

		var impact := ProjectileImpact.new(center)
		impact.managed_enemy = enemy
		impact.collider = collider
		impact.point = hit["point"]
		impact.normal = hit["normal"]

		if contacts.has(enemy):
			var previous: ProjectileImpact = contacts[enemy]
			if previous.point.distance_squared_to(center) <= (
				impact.point.distance_squared_to(center)
			):
				continue
		contacts[enemy] = impact

	result.assign(contacts.values())
	return result


static func _enemy_from_collider(collider: Object) -> AbstractEnemy:
	var node := collider as Node
	while node != null:
		if node is AbstractEnemy:
			return node as AbstractEnemy
		node = node.get_parent()
	return null


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

