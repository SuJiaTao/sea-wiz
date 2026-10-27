@abstract
class_name Upgrade
extends Resource

signal applied
signal stripped

var upgrade_target : UpgradeTarget

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
	return can_accumulate_still()

## Returns true if successfully applied
func apply_upgrade() -> bool:
	if (check_preconditions() and can_accumulate_still()) :
		_apply()
		accumulation += 1
		upgrade_target.add_upgrade(self)
		applied.emit()
		return true
	return false


func remove_upgrade() -> void:
	_remove()
	accumulation -= 1
	upgrade_target.remove_upgrade(self)
	stripped.emit()


func is_applied() -> bool:
	return accumulation > 0


func is_equal(upgrade: Upgrade) -> bool:
	return upgrade == self