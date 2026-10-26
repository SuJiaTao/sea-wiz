class_name SpinTestUpgrade
extends TestUpgrade


func _apply() -> void:
	target.is_spinning = true

func _remove() -> void:
	target.is_spinning = false
	target.reset_spin()

