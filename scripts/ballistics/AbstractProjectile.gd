@abstract
extends RefCounted
class_name AbstractProjectile

enum State { FIRING, FLYING, IMPACTING, DELETED }

var position: Vector3
var velocity: Vector3
var radius: float
var renderer: ProjectileBatch
var weapon_source: Script
var age: float = 0.0
var max_lifetime: float = 3.2

var _state: State = State.FIRING
var _should_destroy: bool = false
var _requested_impact: ProjectileImpact = null

func _init(
	initial_position: Vector3,
	initial_velocity: Vector3,
	initial_radius: float,
	batch: ProjectileBatch
) -> void:
	position = initial_position
	velocity = initial_velocity
	radius = initial_radius
	renderer = batch


func request_delete() -> void:
	_should_destroy = true

func request_impact(impact: ProjectileImpact) -> void:
	_requested_impact = impact


func _on_fire() -> void:
	if is_instance_valid(renderer):
		renderer.register(self)


@abstract
func _on_propel(delta: float) -> void


func _on_impact(_impact: ProjectileImpact) -> void:
	pass


func _on_delete() -> void:
	if is_instance_valid(renderer):
		renderer.unregister(self)


func visual_transform() -> Transform3D:
	var direction := Vector3.FORWARD
	if velocity.length_squared() > 0.000001:
		direction = velocity.normalized()
	var up := Vector3.UP
	if absf(direction.dot(up)) > 0.999:
		up = Vector3.RIGHT
	return Transform3D(Basis.looking_at(direction, up), position)


func visual_color() -> Color:
	return Color.WHITE
