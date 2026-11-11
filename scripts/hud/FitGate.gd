extends Node
class_name FitGate

@export var loadout: ShipLoadout
@export var mount: StringName


func _ready() -> void:
	loadout.upgrades_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	(get_parent() as CanvasItem).visible = loadout.is_fitted(mount)
