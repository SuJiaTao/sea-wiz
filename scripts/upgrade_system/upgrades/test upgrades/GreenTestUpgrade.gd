class_name GreenTestUpgrade
extends TestUpgrade


func _apply() -> void:
	target.modulate = Color.GREEN

func _strip() -> void:
	target.modulate = Color.WHITE

