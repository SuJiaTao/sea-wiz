extends Node

@export var buttonA : Button
@export var buttonB : Button
@export var refresh_button : Button
@export var sliderB : Slider

@export var inactive_upgrades_dock : DemoUpgradeDock
@export var active_upgrades_dock : DemoUpgradeDock
@export var unavailable_upgrades_dock : DemoUpgradeDock

@export var providerA : UpgradeProvider
@export var providerB : UpgradeProvider
var provider : UpgradeProvider
@export var slots : int = 4

@export var category_drop_down : OptionButton
@export var categories : Array[String]

func _ready() -> void:
	connect_signals()
	provider = providerA
	provider.build_trees()
	sliderB.value = slots
	category_drop_down.add_item("NONE")
	for c in categories:
		category_drop_down.add_item(c)
	restock()


func connect_signals() -> void:
	sliderB.drag_ended.connect(restock.unbind(1))
	buttonA.pressed.connect(switch_to_A)
	buttonB.pressed.connect(switch_to_B)
	refresh_button.pressed.connect(restock)
	category_drop_down.item_selected.connect(restock.unbind(1))


func switch_to_A() -> void:
	buttonA.disabled = true
	buttonB.disabled = false
	provider = providerA
	restock()


func switch_to_B() -> void:
	buttonB.disabled = true
	buttonA.disabled = false
	provider = providerB
	restock()


func reset() -> void:
	inactive_upgrades_dock.clear()
	unavailable_upgrades_dock.clear()


func restock() -> void:
	reset()
	var new_upgrades : Array[Upgrade]
	if buttonA.disabled:
		var filter : String = category_drop_down.get_item_text(category_drop_down.get_selected_id())
		if filter == "NONE":
			new_upgrades = provider.get_new_upgrades(sliderB.value as int)
		else:
			new_upgrades = provider.get_new_upgrades_of_category(sliderB.value as int, filter)
	else:
		new_upgrades = provider.get_new_upgrades_weighted(sliderB.value as int)

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
