@abstract
extends Node
class_name AbstractDeckWeapon

@export var fitting: StringName

var _enabled: bool = true


func set_enabled(value: bool) -> void:
	_enabled = value


func trigger() -> void:
	if _enabled:
		_trigger()


func restock() -> void:
	pass


@abstract
func _trigger() -> void
