class_name HasPurpleCircleTestUpgrade
extends TestUpgrade


func _apply() -> void:
	target.purple_circle = true


func _remove() -> void:
	target.purple_circle = false