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

	var node := impact.collider as Node
	while node != null:
		if node is AbstractEnemy:
			impact.managed_enemy = node as AbstractEnemy
			break
		node = node.get_parent()
	return impact


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

