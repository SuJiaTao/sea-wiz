extends Node

@export var demo_output : Control
@export var target : DemoUpgradeTarget

const ROTATION_RATE_RAD : float = PI / 4

var rotating : bool = false


func _ready() -> void:
	target.upgrades_changed.connect(update)
	target.spin_was_reset.connect(reset_spin)


func update() -> void:
	rotating = target.is_spinning
	demo_output.modulate = target.modulate
	demo_output.scale = Vector2(1, 1) * (0.3 if target.is_tiny else 1.0)


func _process(delta: float) -> void:
	if rotating:
		demo_output.rotation += ROTATION_RATE_RAD * delta


func reset_spin() -> void:
	demo_output.rotation = 0.0
