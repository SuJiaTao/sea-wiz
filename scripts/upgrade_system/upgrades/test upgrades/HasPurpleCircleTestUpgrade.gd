class_name HasPurpleCircleTestUpgrade
extends TestUpgrade


func _apply() -> void:
	target.purple_circle += 1


func _strip() -> void:
	target.purple_circle -= 1