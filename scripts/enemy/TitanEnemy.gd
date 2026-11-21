extends StrikeAircraft
class_name TitanEnemy

const WEAK_POINT_RADIUS: float = 9.0
const ENGINE_SPACING: float = 18.0
const ENGINE_HEIGHT: float = 6.0
const ENGINE_AFT: float = 22.0
const ENGINE_COUNT: int = 8

@export var orbit_radius: float = 1100.0
@export var orbit_altitude: float = 420.0
@export var salvo_interval: float = 7.0
@export var salvo_size: int = 2
@export var weak_point_multiplier: float = 3.0
@export var wing_half_span: float = 85.0

var _salvo_clock: float = 0.0

@onready var _hurtbox: Area3D = $Hurtbox


func take_damage(
	amount: float,
	world_point: Vector3,
	weapon_source: DamageSource = null
) -> void:
	var local_point := to_local(world_point)
	var on_engine := false
	for index in ENGINE_COUNT:
		var engine := Vector3((index - (ENGINE_COUNT - 1) * 0.5) * ENGINE_SPACING, ENGINE_HEIGHT, ENGINE_AFT)
		if local_point.distance_to(engine) <= WEAK_POINT_RADIUS:
			on_engine = true
	super(amount * (weak_point_multiplier if on_engine else 1.0), world_point, weapon_source)


func _on_flight_created() -> void:
	_hurtbox.collision_layer = COLLISION_LAYER
	_salvo_clock = salvo_interval


func _on_flight_step(delta: float) -> void:
	_salvo_clock -= delta
	if _salvo_clock > 0.0 or missile_scene == null or BlindArc.contains(global_position):
		return
	_salvo_clock = salvo_interval
	for shot in salvo_size:
		var missile := missile_scene.instantiate() as FlyingEnemy
		missile.velocity = velocity
		var wing := global_basis.x * randf_range(-wing_half_span, wing_half_span)
		weapon_launched.emit(missile, Transform3D(Basis.IDENTITY, global_position + wing + LAUNCH_DROP))


func _desired_velocity(_delta: float) -> Vector3:
	return OrbitSteering.direction(global_position, target_position, orbit_radius, orbit_altitude) * speed


func _on_destroy() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.collision_layer = 0
