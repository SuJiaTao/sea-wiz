class_name ShipLoadout
extends UpgradeTarget

signal repair_requested(amount: float)
signal restock_requested(mount: StringName)

var heat_scale: float = 1.0

var _fitted: Array[StringName] = []


func fit(mount: StringName) -> void:
	if not _fitted.has(mount):
		_fitted.append(mount)


func remove(mount: StringName) -> void:
	_fitted.erase(mount)


func is_fitted(mount: StringName) -> bool:
	return _fitted.has(mount)


func request_repair(amount: float) -> void:
	repair_requested.emit(amount)


func request_restock(mount: StringName) -> void:
	restock_requested.emit(mount)


func clear() -> void:
	for upgrade in active_upgrades.duplicate():
		if upgrade.accumulation > 0:
			upgrade.strip_upgrade()
	active_upgrades.clear()
	_fitted.clear()
	heat_scale = 1.0
	upgrades_changed.emit()
