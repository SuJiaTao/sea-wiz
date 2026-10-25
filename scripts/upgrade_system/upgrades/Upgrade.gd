@abstract
class_name Upgrade
extends Resource

@export var label : String = ""
@export_multiline var description : String = ""

@export var category : String = "Default"
@export var weight : float

@abstract func _apply() -> void
@abstract func _remove() -> void

func has_valid_preconditions() -> bool:
	return true

## Returns true if successfully applied
func apply_upgrade() -> bool:
	if (has_valid_preconditions()) :
		_apply()
		return true
	return false

func remove_upgrade() -> void:
	_remove()