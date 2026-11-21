extends StrikeAircraft
class_name HeavyJetEnemy

const ENGINE_WEAK_POINTS: Array[Vector3] = [
	Vector3(-12.5, -2.0, 0.0),
	Vector3(12.5, -2.0, 0.0),
	Vector3(-6.0, -2.0, 0.0),
	Vector3(6.0, -2.0, 0.0),
]

@export var weak_point_radius: float = 3.0
@export var weak_point_multiplier: float = 3.0
@export var bomb_scene: PackedScene
@export var bombs_carried: int = 4
@export var bomb_interval: float = 0.4
@export var stick_lead: float = 75.0

var _bomb_clock: float = 0.0

@onready var _hurtbox: Area3D = $Hurtbox
@onready var _visuals: Node3D = $Visuals


func _on_flight_created() -> void:
	_hurtbox.collision_layer = COLLISION_LAYER


func _on_flight_step(delta: float) -> void:
	_bomb_clock = maxf(_bomb_clock - delta, 0.0)
	if bomb_scene == null or bombs_carried <= 0 or _bomb_clock > 0.0:
		return
	if BlindArc.contains(global_position):
		return
	var height := maxf(global_position.y - target_position.y, 1.0)
	var fall_time := sqrt(2.0 * height / GRAVITY)
	var offset := target_position - global_position
	if Vector2(offset.x, offset.z).length() <= speed * fall_time + stick_lead:
		_drop_bomb()


func _drop_bomb() -> void:
	bombs_carried -= 1
	_bomb_clock = bomb_interval
	var bomb := bomb_scene.instantiate() as BombEnemy
	bomb.velocity = velocity
	bomb.target_position = target_position
	weapon_launched.emit(bomb, Transform3D(Basis.IDENTITY, global_position))


func take_damage(
	amount: float,
	world_point: Vector3,
	weapon_source: DamageSource = null
) -> void:
	var local_point := _visuals.to_local(world_point)
	var radius_squared := weak_point_radius * weak_point_radius
	for point in ENGINE_WEAK_POINTS:
		if local_point.distance_squared_to(point) <= radius_squared:
			super(amount * weak_point_multiplier, world_point, weapon_source)
			return
	super(amount, world_point, weapon_source)


func _on_destroy() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.collision_layer = 0
