class_name HasCircleTestUpgrade
extends TestUpgrade


func _apply() -> void:
	target.has_circle = true


func _remove() -> void:
	target.has_circle = false