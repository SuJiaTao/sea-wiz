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
		var button = build_button(upgrade)
		set_inactive(button)


func set_active(button: Button) -> void:
	button.pressed.connect(set_inactive, ConnectFlags.CONNECT_APPEND_SOURCE_OBJECT | ConnectFlags.CONNECT_ONE_SHOT)
	if button.get_parent() == inactive_upgrades_dock:
		inactive_upgrades_dock.remove_child(button)
	active_upgrades_dock.add_child(button)
	
	

func set_inactive(button: Button) -> void:
	button.pressed.connect(set_active, ConnectFlags.CONNECT_APPEND_SOURCE_OBJECT | ConnectFlags.CONNECT_ONE_SHOT)
	if button.get_parent() == active_upgrades_dock:
		active_upgrades_dock.remove_child(button)
	inactive_upgrades_dock.add_child(button)


func build_button(upgrade: Upgrade) -> Button:
	var button : Button = Button.new()
	button.text = upgrade.label
	button.custom_minimum_size = Vector2(100, 100)
	button.pressed.connect(upgrade.apply_upgrade)
	return button