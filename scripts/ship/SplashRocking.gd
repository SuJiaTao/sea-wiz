extends Node
class_name SplashRocking

@export var effects: EffectManager
@export var sway: ShipSway
@export var vessel: Node3D
@export var reach: float = 260.0
@export var roll_kick_per_size: float = 2.2
@export var pitch_kick_per_size: float = 1.2


func _ready() -> void:
	effects.shockwave.connect(_on_shockwave)


func _on_shockwave(position: Vector3, size: float) -> void:
	var local := vessel.global_transform.affine_inverse() * position
	var distance := Vector2(local.x, local.z).length()
	if distance >= reach:
		return
	var closeness := 1.0 - distance / reach
	var side := Vector2(local.x, local.z).normalized() if distance > 0.0 else Vector2.ZERO
	sway.kick(
		-side.x * roll_kick_per_size * size * closeness,
		side.y * pitch_kick_per_size * size * closeness
	)
