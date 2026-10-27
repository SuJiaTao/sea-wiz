class_name TinyTestUpgrade
extends TestUpgrade


func _apply() -> void:
	target.is_tiny = true


func _strip() -> void:
	target.is_tiny = false
