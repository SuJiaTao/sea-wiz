class_name BlankUpgrade
extends UpgradeGraph


func _apply() -> void:
	print("applied " + label)


func _strip() -> void:
	print("stripped " + label)