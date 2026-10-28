extends Node

@export var button_a : Button
@export var button_b : Button
@export var refresh_button : Button
@export var slider_b : Slider

@export var inactive_upgrades_dock : DemoUpgradeDock
@export var active_upgrades_dock : DemoUpgradeDock
@export var unavailable_upgrades_dock : DemoUpgradeDock

@export var provider_a : UpgradeProvider
@export var provider_b : UpgradeProvider
var provider : UpgradeProvider
@export var slots : int = 4

@export var category_drop_down : OptionButton
@export var categories : Array[String]

func _ready() -> void:
	connect_signals()
	provider = provider_a
	provider.build_trees()
	slider_b.value = slots
	category_drop_down.add_item("NONE")
	for c in categories:
		category_drop_down.add_item(c)
	restock()


func connect_signals() -> void:
	slider_b.drag_ended.connect(restock.unbind(1))
	button_a.pressed.connect(switch_to_b)
	button_b.pressed.connect(switch_to_a)
	refresh_button.pressed.connect(restock)
	category_drop_down.item_selected.connect(restock.unbind(1))


func switch_to_b() -> void:
	button_a.disabled = true
	button_b.disabled = false
	provider = provider_a
	restock()


func switch_to_a() -> void:
	button_b.disabled = true
	button_a.disabled = false
	provider = provider_b
	restock()


func reset() -> void:
	inactive_upgrades_dock.clear()
	unavailable_upgrades_dock.clear()


func restock() -> void:
	reset()
	var new_upgrades : Array[Upgrade]
	if button_a.disabled:
		var filter : String = category_drop_down.get_item_text(category_drop_down.get_selected_id())
		if filter == "NONE":
			new_upgrades = provider.get_new_upgrades(slider_b.value as int)
		else:
			new_upgrades = provider.get_new_upgrades_of_category(slider_b.value as int, filter)
	else:
		new_upgrades = provider.get_new_upgrades_weighted(slider_b.value as int)

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
