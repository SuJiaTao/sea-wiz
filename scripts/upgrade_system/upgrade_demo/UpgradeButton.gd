class_name UpgradeButton
extends Button

var upgrade : Upgrade
var active : bool = false


func _init(new_upgrade: Upgrade) -> void:
	text = new_upgrade.label
	custom_minimum_size = Vector2(100, 100)
	upgrade = new_upgrade


func process_upgrade() -> void:
	if active:
		upgrade.apply_upgrade()
	else:
		upgrade.remove_upgrade()