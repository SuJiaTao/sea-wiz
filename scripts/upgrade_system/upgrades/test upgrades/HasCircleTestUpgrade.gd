class_name HasCircleTestUpgrade
extends TestUpgrade


func _apply() -> void:
	target.has_circle = true


func _strip() -> void:
	target.has_circle = false