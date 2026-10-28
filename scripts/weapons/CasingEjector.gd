extends Node
class_name CasingEjector

@export var turret: Turret
@export var pile: CasingPile
@export var port_offset := Vector3(0.6, -0.9, 0.2)
@export var throw_speed := Vector2(5.0, 8.0)
@export var throw_forward: float = 1.0
@export var throw_lift: float = 0.8
@export var scatter: float = 0.9


func _ready() -> void:
	turret.fired.connect(_on_fired)


func _on_fired(_origin: Vector3, _velocity: Vector3) -> void:
	var mount := turret.mount
	var sideways := mount.global_basis.x
	var forward := -mount.global_basis.z
	var throw := (
		(sideways + forward * throw_forward).normalized() * randf_range(throw_speed.x, throw_speed.y)
		+ Vector3.UP * throw_lift
		+ ParticleBatch.random_direction() * scatter
	)
	pile.eject(mount.global_transform * port_offset, throw)
