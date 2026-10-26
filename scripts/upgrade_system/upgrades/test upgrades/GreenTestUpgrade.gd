class_name GreenTestUpgrade
extends TestUpgrade


func _apply() -> void:
	target.modulate = Color.GREEN

func _remove() -> void:
	target.modulate = Color.WHITE

