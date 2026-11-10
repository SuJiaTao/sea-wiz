@abstract
extends Node
class_name AbstractDeckWeapon
## A ship weapon that fires on its own key, outside the CIWS mount.

var _enabled: bool = true


func set_enabled(value: bool) -> void:
	_enabled = value


func handle_input(event: InputEvent) -> bool:
	if not event.is_action_pressed(_action()):
		return false
	_trigger()
	return true


@abstract
func _action() -> StringName


@abstract
func _trigger() -> void
