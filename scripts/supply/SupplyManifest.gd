extends Node
class_name SupplyManifest

signal opened
signal closed(choice: Upgrade)

const OFFER_COUNT: int = 3
const SLOW_TIME_SCALE: float = 0.08
const PICK_ACTIONS: Array[StringName] = [&"supply_pick_1", &"supply_pick_2", &"supply_pick_3"]

@export var provider: UpgradeProvider

var offers: Array[Upgrade] = []


func _ready() -> void:
	provider.build_trees()
	Engine.time_scale = 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func is_open() -> bool:
	return not offers.is_empty()


func open() -> void:
	offers = provider.get_new_upgrades_weighted(OFFER_COUNT)
	if offers.is_empty():
		return
	Engine.time_scale = SLOW_TIME_SCALE
	opened.emit()


func dismiss() -> void:
	offers.clear()
	Engine.time_scale = 1.0


func handle_input(event: InputEvent) -> bool:
	if not is_open():
		return false
	for index in mini(offers.size(), PICK_ACTIONS.size()):
		if event.is_action_pressed(PICK_ACTIONS[index]):
			_choose(offers[index])
			return true
	return false


func _choose(upgrade: Upgrade) -> void:
	dismiss()
	upgrade.apply_upgrade()
	closed.emit(upgrade)
