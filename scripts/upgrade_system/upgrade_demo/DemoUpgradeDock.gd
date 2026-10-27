class_name DemoUpgradeDock
extends Container

var _button_pool : Array[DemoUpgradeButton]

@export var disabled : bool = false

## Adds a DemoUpgradeButton with given upgrade as child, does nothing if the same Upgrade resource is already assigned a button.
func dock(upgrade: Upgrade, active: bool) -> void:
	if already_docked(upgrade):
		return
	var button = _retrieve_button(upgrade)
	if not button:
		var new_button : DemoUpgradeButton = DemoUpgradeButton.new(upgrade, active)
		if not disabled:
			if active:
				new_button.pressed.connect(upgrade.remove_upgrade)
			else:
				new_button.pressed.connect(upgrade.apply_upgrade)
		add_child(new_button)
	else:
		button.upgrade = upgrade	
		add_child(button)
	


func undock(upgrade: Upgrade) -> void:
	var button = _find_upgrade_button(upgrade)
	if button == null:
		return
	remove_child(button)
	_button_pool.append(button)


func _find_upgrade_button(upgrade: Upgrade) -> DemoUpgradeButton:
	for child in get_children():
		if child.upgrade == upgrade:
			return child
	return null


func _retrieve_button(upgrade: Upgrade) -> DemoUpgradeButton:
	for button in _button_pool:
		if button.upgrade == upgrade:
			return button
	return null


func already_docked(upgrade: Upgrade) -> bool:
	return (_find_upgrade_button(upgrade) != null)