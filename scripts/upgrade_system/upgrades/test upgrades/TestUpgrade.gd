class_name TestUpgrade
extends Upgrade

var target : DemoUpgradeTarget = load("res://scripts/upgrade_system/recievers/resources/DemoUpgradeTarget.tres")

func _apply() -> void:
	pass

func _remove() -> void:
	pass


func apply_upgrade() -> bool:
	if super.apply_upgrade():
		target.add_upgrade(self)
		return true
	return false

func remove_upgrade() -> void:
	super.remove_upgrade()
	target.remove_upgarde(self)

