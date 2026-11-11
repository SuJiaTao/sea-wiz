class_name MountUpgrade
extends LoadoutUpgrade

@export var mount: StringName
@export var slot: ShipLoadout.Slot = ShipLoadout.Slot.PASSIVE


func _apply() -> void:
	loadout.fit(mount, slot)


func _strip() -> void:
	loadout.remove(mount)
