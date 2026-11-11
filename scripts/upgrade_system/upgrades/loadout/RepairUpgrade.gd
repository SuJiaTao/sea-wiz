class_name RepairUpgrade
extends LoadoutUpgrade

@export var amount: float = 40.0


func _apply() -> void:
	loadout.request_repair(amount)


func _strip() -> void:
	pass
