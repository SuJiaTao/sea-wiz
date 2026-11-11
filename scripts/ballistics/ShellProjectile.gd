extends AbstractProjectile
class_name ShellProjectile

signal detonated(position: Vector3, radius: float)

const GRAVITY: float = 9.81
const FLIGHT_TIME: float = 9.0
const FUZE_RADIUS: float = 9.0
const BLAST_RADIUS: float = 24.0
const WARHEAD: float = 420.0
const FALLOFF_POWER: float = 0.5
const TRACER_LENGTH: float = 14.0
const TRACER_WIDTH: float = 1.6
const TRACER_HEAT := Color(1.6, 1.4, 1.1, 1.0)
const WATER_SPLASH_SIZE: float = 2.4

var _ballistics: BallisticManager


func _init(
	batch: ProjectileBatch,
	ballistics: BallisticManager,
	origin: Vector3,
	initial_velocity: Vector3
) -> void:
	super(origin, initial_velocity, 0.0, batch)
	_ballistics = ballistics
	max_lifetime = FLIGHT_TIME


func _on_propel(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	position += velocity * delta
	var contacts := _ballistics.sphere_contacts(position, FUZE_RADIUS)
	if not contacts.is_empty():
		request_impact(contacts[0])


func _on_impact(_impact: ProjectileImpact) -> void:
	detonated.emit(position, BLAST_RADIUS)
	for contact in _ballistics.sphere_contacts(position, BLAST_RADIUS):
		var enemy := contact.managed_enemy
		if not is_instance_valid(enemy):
			continue
		var distance := position.distance_to(contact.point)
		var falloff := pow(
			clampf(1.0 - distance / BLAST_RADIUS, 0.0, 1.0),
			FALLOFF_POWER
		)
		enemy.take_damage(WARHEAD * falloff, position, weapon_source)


func _splash_size() -> float:
	return WATER_SPLASH_SIZE


func visual_transform() -> Transform3D:
	var result := super()
	result.basis *= Basis.from_scale(Vector3(TRACER_WIDTH, TRACER_WIDTH, TRACER_LENGTH))
	return result


func visual_color() -> Color:
	return TRACER_HEAT
