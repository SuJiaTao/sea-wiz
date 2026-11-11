class_name CoolingUpgrade
extends LoadoutUpgrade

@export var heat_factor: float = 0.75


func _apply() -> void:
	loadout.heat_scale *= heat_factor


func _strip() -> void:
	loadout.heat_scale /= heat_factor
