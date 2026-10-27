class_name CloneTestUpgrade
extends TestUpgrade


func _apply() -> void:
	target.clones += 1


func _strip() -> void:
	target.clones -= 1
