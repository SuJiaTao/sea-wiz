class_name RestockUpgrade
extends LoadoutUpgrade

@export var mount: StringName


func _apply() -> void:
	loadout.request_restock(mount)


func _strip() -> void:
	pass
