extends AbstractProjectile
class_name BulletProjectile

const GRAVITY := 9.81
const GLANCING_INCIDENCE := 0.5
const RICOCHET_CHANCE := 0.8
const MAX_RICOCHETS := 1
const RICOCHET_SPEED_KEPT := 0.45
const RICOCHET_DAMAGE_KEPT := 0.25
const RICOCHET_SCATTER := 0.2
const SURFACE_CLEARANCE := 0.05
const MIN_NORMAL_LENGTH_SQUARED := 0.5
const FLIGHT_TIME := 5.0
const TRACER_HEAT := Color(9.0, 9.0, 8.0, 1.0)
const BURNOUT_TIME := 0.5
const BURNOUT_FLOOR := 0.6
const IGNITION_TIME := 0.03
const IGNITION_FLOOR := 0.5
const MIN_TRACER := 0.5

var damage: float = 40.0
var tracer_length: float = 12.0

var _ricochets: int = 0
var _muzzle: Vector3


func _init(
	batch: ProjectileBatch,
	origin: Vector3,
	initial_velocity: Vector3
) -> void:
	super(origin, initial_velocity, 0.0, batch)
	max_lifetime = FLIGHT_TIME
	_muzzle = origin


func _on_propel(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	position += velocity * delta


func _on_impact(impact: ProjectileImpact) -> void:
	var enemy := impact.managed_enemy
	if not is_instance_valid(enemy):
		return
	if enemy.alive and not enemy._destroy_requested:
		enemy.take_damage(damage, impact.point, weapon_source)


func _deflects(impact: ProjectileImpact) -> bool:
	if _ricochets >= MAX_RICOCHETS:
		return false
	if impact.normal.length_squared() < MIN_NORMAL_LENGTH_SQUARED:
		return false
	var incidence := absf(velocity.normalized().dot(impact.normal))
	return incidence < GLANCING_INCIDENCE and randf() < RICOCHET_CHANCE


func _on_deflect(impact: ProjectileImpact) -> void:
	_ricochets += 1
	damage *= RICOCHET_DAMAGE_KEPT
	_on_impact(impact)
	var bounced := velocity.bounce(impact.normal)
	var scatter := Vector3(randfn(0.0, 1.0), randfn(0.0, 1.0), randfn(0.0, 1.0))
	var direction := (bounced.normalized() + scatter * RICOCHET_SCATTER).normalized()
	velocity = direction * bounced.length() * RICOCHET_SPEED_KEPT
	position = impact.point + impact.normal * SURFACE_CLEARANCE


## The tracer trails back over the ground it covered since the last physics
## step (the batch draws it a little ahead to smooth motion), so a fast round
## still draws a line from the muzzle out, and never behind the muzzle.
func visual_transform() -> Transform3D:
	var result := super()
	var speed := velocity.length()
	var step := 1.0 / Engine.physics_ticks_per_second
	var lead := speed * Engine.get_physics_interpolation_fraction() * step
	var streak := maxf(tracer_length, speed * step + lead)
	var drawn := minf(streak, position.distance_to(_muzzle) + lead)
	result.basis *= Basis.from_scale(Vector3(1.0, 1.0, maxf(drawn, MIN_TRACER)))
	return result


func visual_color() -> Color:
	var fade := clampf((max_lifetime - age) / BURNOUT_TIME, BURNOUT_FLOOR, 1.0)
	fade *= lerpf(IGNITION_FLOOR, 1.0, clampf(age / IGNITION_TIME, 0.0, 1.0))
	return Color(TRACER_HEAT.r * fade, TRACER_HEAT.g * fade, TRACER_HEAT.b * fade, 1.0)
