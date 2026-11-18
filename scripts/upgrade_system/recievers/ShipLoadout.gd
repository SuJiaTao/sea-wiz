class_name ShipLoadout
extends UpgradeTarget

signal repair_requested(amount: float)
signal restock_requested(mount: StringName)

enum Slot { PASSIVE, WEAPON, SYSTEM }

const EMPTY := &""
const WEAPON_ACTIONS: Array[StringName] = [&"weapon_1", &"weapon_2", &"weapon_3", &"weapon_4"]
const SYSTEM_ACTIONS: Array[StringName] = [&"system_1", &"system_2"]
const WEAPON_KEYS: Array[String] = ["Q", "W", "E", "R"]
const SYSTEM_KEYS: Array[String] = ["F", "G"]

var heat_scale: float = 1.0

var _passives: Array[StringName] = []
var _weapons: Array[StringName] = [EMPTY, EMPTY, EMPTY, EMPTY]
var _systems: Array[StringName] = [EMPTY, EMPTY]


func fit(mount: StringName, slot: Slot = Slot.PASSIVE) -> void:
	if is_fitted(mount):
		return
	match slot:
		Slot.WEAPON:
			_place(_weapons, mount)
		Slot.SYSTEM:
			_place(_systems, mount)
		_:
			_passives.append(mount)


func remove(mount: StringName) -> void:
	_passives.erase(mount)
	for slots in [_weapons, _systems]:
		var index: int = slots.find(mount)
		if index >= 0:
			slots[index] = EMPTY


func is_fitted(mount: StringName) -> bool:
	return _passives.has(mount) or _weapons.has(mount) or _systems.has(mount)


func has_room(slot: Slot) -> bool:
	match slot:
		Slot.WEAPON:
			return _weapons.has(EMPTY)
		Slot.SYSTEM:
			return _systems.has(EMPTY)
	return true


func occupants(slot: Slot) -> Array[Upgrade]:
	var found: Array[Upgrade] = []
	for mount in (_weapons if slot == Slot.WEAPON else _systems):
		var upgrade := upgrade_for(mount)
		if upgrade != null:
			found.append(upgrade)
	return found


func upgrade_for(mount: StringName) -> Upgrade:
	for upgrade in active_upgrades:
		if upgrade is MountUpgrade and (upgrade as MountUpgrade).mount == mount:
			return upgrade
	return null


func action_for(mount: StringName) -> StringName:
	var weapon := _weapons.find(mount)
	if mount != EMPTY and weapon >= 0:
		return WEAPON_ACTIONS[weapon]
	var system := _systems.find(mount)
	if mount != EMPTY and system >= 0:
		return SYSTEM_ACTIONS[system]
	return EMPTY


func key_for(mount: StringName) -> String:
	var weapon := _weapons.find(mount)
	if weapon >= 0:
		return WEAPON_KEYS[weapon]
	var system := _systems.find(mount)
	if system >= 0:
		return SYSTEM_KEYS[system]
	return ""


func row_for(mount: StringName) -> int:
	var weapon := _weapons.find(mount)
	if weapon >= 0:
		return weapon
	var system := _systems.find(mount)
	if system >= 0:
		return _weapons.size() + system
	return -1


func request_repair(amount: float) -> void:
	repair_requested.emit(amount)


func request_restock(mount: StringName) -> void:
	restock_requested.emit(mount)


func clear() -> void:
	for upgrade in active_upgrades.duplicate():
		if upgrade.accumulation > 0:
			upgrade.strip_upgrade()
	active_upgrades.clear()
	_passives.clear()
	_weapons = [EMPTY, EMPTY, EMPTY, EMPTY]
	_systems = [EMPTY, EMPTY]
	heat_scale = 1.0
	upgrades_changed.emit()


func _place(slots: Array[StringName], mount: StringName) -> void:
	var index := slots.find(EMPTY)
	if index >= 0:
		slots[index] = mount
