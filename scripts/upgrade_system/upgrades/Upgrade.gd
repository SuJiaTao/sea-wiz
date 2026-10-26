@abstract
class_name Upgrade
extends Resource

@export var label : String = ""
@export_multiline var description : String = ""

@export var category : String = "Default"
@export var weight : float = 1.0

@abstract func _apply() -> void
@abstract func _remove() -> void

var accumulation : int = 0
@export var max_acummulation : int = 1

func can_accumulate_still() -> bool:
	return not (accumulation == max_acummulation)

func check_preconditions() -> bool:
	return true

## Returns true if successfully applied
func apply_upgrade() -> bool:
	if (check_preconditions() and can_accumulate_still()) :
		_apply()
		accumulation += 1
		return true
	return false

func remove_upgrade() -> void:
	accumulation -= 1
	_remove()