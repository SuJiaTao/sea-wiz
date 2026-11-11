extends Node
class_name SupplyManifest

signal opened
signal closed(choice: Upgrade)

const OFFER_COUNT: int = 3
const SLOW_TIME_SCALE: float = 0.08
const PICK_ACTIONS: Array[StringName] = [&"supply_pick_1", &"supply_pick_2", &"supply_pick_3"]
const DISCARD_PICK: int = 2

@export var provider: UpgradeProvider
@export var loadout: ShipLoadout

var offers: Array[Upgrade] = []
var pending: MountUpgrade


func _ready() -> void:
	provider.build_trees()
	Engine.time_scale = 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func is_open() -> bool:
	return not offers.is_empty()


func is_replacing() -> bool:
	return pending != null


func open() -> void:
	pending = null
	offers = provider.get_new_upgrades_weighted(OFFER_COUNT)
	if offers.is_empty():
		return
	Engine.time_scale = SLOW_TIME_SCALE
	opened.emit()


func dismiss() -> void:
	offers.clear()
	pending = null
	Engine.time_scale = 1.0


func handle_input(event: InputEvent) -> bool:
	if not is_open():
		return false
	for index in PICK_ACTIONS.size():
		if not event.is_action_pressed(PICK_ACTIONS[index]):
			continue
		if is_replacing():
			_replace(index)
		elif index < offers.size():
			_choose(offers[index])
		return true
	return false


func _choose(upgrade: Upgrade) -> void:
	var mount := upgrade as MountUpgrade
	if mount != null and not loadout.has_room(mount.slot):
		pending = mount
		offers = loadout.occupants(mount.slot).filter(
			func(occupant: Upgrade) -> bool: return not mount.predecessors.has(occupant)
		)
		return
	dismiss()
	upgrade.apply_upgrade()
	closed.emit(upgrade)


func _replace(index: int) -> void:
	var incoming := pending
	if index == DISCARD_PICK:
		dismiss()
		closed.emit(null)
		return
	if index >= offers.size():
		return
	var outgoing := offers[index]
	dismiss()
	if outgoing is UpgradeGraph:
		(outgoing as UpgradeGraph).force_strip()
	else:
		outgoing.strip_upgrade()
	incoming.apply_upgrade()
	closed.emit(incoming)
