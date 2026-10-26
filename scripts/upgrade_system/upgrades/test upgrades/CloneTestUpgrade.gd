class_name CloneTestUpgrade
extends TestUpgrade


func _apply() -> void:
	target.clones += 1


func _remove() -> void:
	target.clones -= 1
