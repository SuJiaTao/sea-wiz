class_name DemoUpgradeButton
extends Button

var upgrade : Upgrade
var active : bool = false


func _init(new_upgrade: Upgrade, is_active: bool) -> void:
	text = new_upgrade.label
	custom_minimum_size = Vector2(100, 100)
	upgrade = new_upgrade
	active = is_active
# 	pressed.connect(_process_upgrade)


# func _process_upgrade() -> void:
# 	if not active:
# 		upgrade.apply_upgrade()
# 	else:
# 		upgrade.remove_upgrade()