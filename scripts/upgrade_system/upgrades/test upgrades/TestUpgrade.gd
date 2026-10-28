@abstract
class_name TestUpgrade
extends UpgradeGraph

var target : DemoUpgradeTarget = load("res://scripts/upgrade_system/recievers/resources/demo_upgrade-target.tres")

func _init() -> void:
	upgrade_target = target

