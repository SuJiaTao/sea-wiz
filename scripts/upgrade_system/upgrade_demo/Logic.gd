extends Node

@export var inactive_upgrades_dock : Container
@export var active_upgrades_dock : Container

@export var provider : UpgradeProvider
@export var upgrade_count : int = 4


func _ready() -> void:
	restock()


func restock() -> void:
	var new_upgrades : Array[Upgrade] = provider.get_new_upgrades(upgrade_count)
	for upgrade in new_upgrades:
		var button = UpgradeButton.new(upgrade)
		button.pressed.connect(process_button, ConnectFlags.CONNECT_APPEND_SOURCE_OBJECT)
		inactive_upgrades_dock.add_child(button)


func set_active(button: UpgradeButton) -> void:
	button.active = true
	button.process_upgrade()
	if button.upgrade.can_accumulate_still():
		button.active = false
		return
	if button.get_parent() == inactive_upgrades_dock:
		inactive_upgrades_dock.remove_child(button)
	active_upgrades_dock.add_child(button)
	
	

func set_inactive(button: UpgradeButton) -> void:
	button.active = false
	button.process_upgrade()
	if button.upgrade.accumulation > 0:
		button.active = true
		return
	if button.get_parent() == active_upgrades_dock:
		active_upgrades_dock.remove_child(button)
	inactive_upgrades_dock.add_child(button)


func process_button(button: UpgradeButton) -> void:
	if button.active:
		set_inactive(button)
	else:
		set_active(button)
