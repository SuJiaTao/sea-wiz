class_name SuperSpinTestUpgrade
extends TestUpgrade


func _apply() -> void:
	target.is_super_spin = true


func _strip() -> void:
	target.is_super_spin = false
	
