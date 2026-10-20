extends AbstractProjectile
class_name BulletProjectile

signal hit_enemy(enemy: Enemy, world_point: Vector3, killed: bool)
signal round_expired()

const GRAVITY := 9.81

var damage: float = 10.0
var tracer_length: float = 8.0


func _init(
	batch: ProjectileBatch,
	origin: Vector3,
	initial_velocity: Vector3
) -> void:
	super(origin, initial_velocity, 0.0, batch)


func _on_propel(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	position += velocity * delta


func _on_impact(impact: ProjectileImpact) -> void:
	if is_instance_valid(impact.enemy) and impact.enemy.alive:
		var killed := impact.enemy.take_damage(damage, impact.point)
		hit_enemy.emit(impact.enemy, impact.point, killed)


func _on_delete(reason: DeleteReason) -> void:
	super(reason)
	if reason in [DeleteReason.GROUND, DeleteReason.EXPIRED, DeleteReason.RANGE]:
		round_expired.emit()


func visual_transform() -> Transform3D:
	var result := super()
	result.basis *= Basis.from_scale(Vector3(1.0, 1.0, tracer_length))
	return result


func visual_color() -> Color:
	var fade := clampf((max_lifetime - age) / 1.4, 0.45, 1.0)
	return Color(2.6 * fade, 2.6 * fade, 2.2 * fade, 1.0)


static func make_mesh() -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.085, 0.085, 1.0)
	mesh.material = ProjectileBatch.make_material()
	return mesh
