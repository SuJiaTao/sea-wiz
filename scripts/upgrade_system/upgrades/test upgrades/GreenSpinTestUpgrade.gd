class_name GreenSpinTestUpgrade
extends TestUpgrade


func _apply() -> void:
	target.green_spin = true


func _remove() -> void:
	target.green_spin = false