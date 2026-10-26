@abstract
class_name UpgradeTarget
extends Resource

signal upgrades_changed

var active_upgrades : Array[Upgrade]


func add_upgrade(upgrade: Upgrade) -> void:
	active_upgrades.append(upgrade)
	upgrades_changed.emit()


func remove_upgarde(upgrade: Upgrade) -> void:
	active_upgrades.erase(upgrade)
	upgrades_changed.emit()
