class_name DemoUpgradeTarget
extends UpgradeTarget

signal spin_was_reset

var is_spinning : bool = false
var modulate	: Color = Color.WHITE
var is_tiny		: bool = false
var clones		: int = 0
var is_super_spin : bool = false
var has_circle : bool = false
var purple_circle : bool = false
var green_spin : bool = false


func reset_spin() -> void:
	spin_was_reset.emit()
