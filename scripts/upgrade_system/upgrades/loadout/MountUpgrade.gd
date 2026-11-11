class_name MountUpgrade
extends LoadoutUpgrade

@export var mount: StringName


func _apply() -> void:
	loadout.fit(mount)


func _strip() -> void:
	loadout.remove(mount)
