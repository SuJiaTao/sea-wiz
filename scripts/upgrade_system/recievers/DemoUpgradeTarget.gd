class_name DemoUpgradeTarget
extends UpgradeTarget

signal spin_was_reset

var is_spinning : bool = false
var modulate	: Color = Color.WHITE
var is_tiny		: bool = false
var clones		: int = 0


func reset_spin() -> void:
	spin_was_reset.emit()
