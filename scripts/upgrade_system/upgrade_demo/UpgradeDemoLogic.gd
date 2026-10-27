extends Node

@export var buttonA : Button
@export var buttonB : Button
@export var sliderB : Slider

@export var inactive_upgrades_dock : DemoUpgradeDock
@export var active_upgrades_dock : DemoUpgradeDock
@export var unavailable_upgrades_dock : DemoUpgradeDock

@export var providerA : UpgradeProvider
@export var providerB : UpgradeProvider
var provider : UpgradeProvider
@export var slots : int = 4


func _ready() -> void:
	provider = providerA
	provider.build_trees()
	restock()
	sliderB.value = 3
	sliderB.drag_ended.connect(restock.unbind(1))
	buttonA.pressed.connect(switch_to_A)
	buttonB.pressed.connect(switch_to_B)


func switch_to_A() -> void:
	buttonA.disabled = true
	buttonB.disabled = false
	sliderB.hide()
	provider = providerA
	restock()


func switch_to_B() -> void:
	buttonB.disabled = true
	buttonA.disabled = false
	sliderB.show()
	provider = providerB
	restock()


func reset() -> void:
	inactive_upgrades_dock.clear()
	unavailable_upgrades_dock.clear()


func restock() -> void:
	reset()
	var new_upgrades : Array[Upgrade]
	if buttonA.disabled:
		new_upgrades = provider.get_new_upgrades(slots)
	else:
		new_upgrades = provider.get_new_upgrades(sliderB.value as int)

	for upgrade in new_upgrades:
		inactive_upgrades_dock.dock(upgrade, false)
		if not upgrade.applied.is_connected(set_active):
			upgrade.applied.connect(set_active, ConnectFlags.CONNECT_APPEND_SOURCE_OBJECT)
		if not upgrade.stripped.is_connected(set_inactive):
			upgrade.stripped.connect(set_inactive, ConnectFlags.CONNECT_APPEND_SOURCE_OBJECT)

	var unavailables : Array[Upgrade] = provider.get_unavailable_upgrades()
	if not unavailables.is_empty():
		for upgrade in unavailables:
			unavailable_upgrades_dock.dock(upgrade, false)
		


func set_active(upgrade: Upgrade) -> void:
	if not upgrade.can_accumulate_still():
		inactive_upgrades_dock.undock(upgrade)
	active_upgrades_dock.dock(upgrade, true)
	restock()


func set_inactive(upgrade: Upgrade) -> void:
	if upgrade.accumulation == 0:
		active_upgrades_dock.undock(upgrade)
	inactive_upgrades_dock.dock(upgrade, false)
	restock()

