extends AbstractProjectile
class_name BulletProjectile

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
	var enemy := impact.managed_enemy
	if not is_instance_valid(enemy):
		return
	if enemy.alive and not enemy._destroy_requested:
		enemy.take_damage(damage, impact.point, weapon_source)


func visual_transform() -> Transform3D:
	var result := super()
	result.basis *= Basis.from_scale(Vector3(1.0, 1.0, tracer_length))
	return result


func visual_color() -> Color:
	var fade := clampf((max_lifetime - age) / 1.4, 0.45, 1.0)
	return Color(2.6 * fade, 2.6 * fade, 2.2 * fade, 1.0)
