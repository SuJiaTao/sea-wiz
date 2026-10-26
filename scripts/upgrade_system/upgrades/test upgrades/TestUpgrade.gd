class_name TestUpgrade
extends Upgrade

var target : DemoUpgradeTarget = load("res://scripts/upgrade_system/recievers/resources/DemoUpgradeTarget.tres")

func _init() -> void:
	upgrade_target = target


func _apply() -> void:
	pass

func _remove() -> void:
	pass

