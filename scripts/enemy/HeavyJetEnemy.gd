extends FlyingEnemy
class_name HeavyJetEnemy

const ENGINE_WEAK_POINTS: Array[Vector3] = [
	Vector3(-12.5, -2.0, 0.0),
	Vector3(12.5, -2.0, 0.0),
	Vector3(-6.0, -2.0, 0.0),
	Vector3(6.0, -2.0, 0.0),
]

@export var weak_point_radius: float = 3.0
@export var weak_point_multiplier: float = 3.0

@onready var _hurtbox: Area3D = $Hurtbox
@onready var _visuals: Node3D = $Visuals


func _on_flight_created() -> void:
	_hurtbox.collision_layer = COLLISION_LAYER


func _desired_velocity(_delta: float) -> Vector3:
	return (target_position - global_position).normalized() * speed


func take_damage(amount: float, world_point: Vector3) -> void:
	var local_point := _visuals.to_local(world_point)
	var radius_squared := weak_point_radius * weak_point_radius
	for point in ENGINE_WEAK_POINTS:
		if local_point.distance_squared_to(point) <= radius_squared:
			super(amount * weak_point_multiplier, world_point)
			return
	super(amount, world_point)


func _on_destroy() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.collision_layer = 0
