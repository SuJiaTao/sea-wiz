@abstract
class_name LoadoutUpgrade
extends UpgradeGraph

const LOADOUT_PATH := "res://scripts/upgrade_system/recievers/resources/ship_loadout.tres"

var loadout: ShipLoadout = load(LOADOUT_PATH)


func _init() -> void:
	upgrade_target = loadout
