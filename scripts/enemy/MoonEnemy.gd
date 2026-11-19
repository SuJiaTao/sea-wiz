extends AbstractEnemy
class_name MoonEnemy

# The moon itself, torn out of the sky and thrown at us. It sets off exactly
# where it hung and the size it looked, comes on slowly and then faster, and
# cracks open with light as it is shot. If it arrives, nothing survives.

const CRACKS := &"cracks"

@export var target_position := Vector3.ZERO
@export var start_speed: float = 20.0
@export var top_speed: float = 150.0
@export var acceleration: float = 2.5
@export var impact_damage: float = 1000.0
@export var spin_rate: float = 0.05
@export var surface: GeometryInstance3D

var _speed: float = 0.0

@onready var _hurtbox: Area3D = $Hurtbox


func _create() -> void:
	_hurtbox.collision_layer = COLLISION_LAYER
	_speed = start_speed


func _on_think(delta: float) -> void:
	_speed = minf(_speed + acceleration * delta, top_speed)
	var offset := target_position - global_position
	velocity = offset.normalized() * _speed
	global_position += velocity * delta
	visuals.rotate_y(spin_rate * delta)
	if offset.length() <= hud_radius:
		reached_target.emit(impact_damage)
		request_destroy()


func _on_damage(_amount: float, _world_point: Vector3) -> void:
	surface.set_instance_shader_parameter(CRACKS, 1.0 - hp / max_hp)
