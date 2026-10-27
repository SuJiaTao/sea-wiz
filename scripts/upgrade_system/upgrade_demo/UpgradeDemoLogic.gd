extends Node

@export var inactive_upgrades_dock : DemoUpgradeDock
@export var active_upgrades_dock : DemoUpgradeDock
@export var unavailable_upgrades_dock : DemoUpgradeDock

@export var provider : UpgradeProvider
@export var upgrade_count : int = 4


func _ready() -> void:
	restock()


func restock() -> void:
	var new_upgrades : Array[Upgrade] = provider.get_new_upgrades(upgrade_count)
	for upgrade in new_upgrades:
		inactive_upgrades_dock.dock(upgrade, false)
		upgrade.applied.connect(set_active, ConnectFlags.CONNECT_APPEND_SOURCE_OBJECT)
		upgrade.stripped.connect(set_inactive, ConnectFlags.CONNECT_APPEND_SOURCE_OBJECT)


func set_active(upgrade: Upgrade) -> void:
	if not upgrade.can_accumulate_still():
		inactive_upgrades_dock.undock(upgrade)
	active_upgrades_dock.dock(upgrade, true)


func set_inactive(upgrade: Upgrade) -> void:
	if upgrade.accumulation == 0:
		active_upgrades_dock.undock(upgrade)
	inactive_upgrades_dock.dock(upgrade, false)


