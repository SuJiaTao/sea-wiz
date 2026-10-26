## A class graph representing an "upgrade tree", the graph flows backwards with no backtracks, starting from the end of an upgrade tree.
@abstract
class_name UpgradeGraph
extends Upgrade

signal is_being_stripped

@export var predecessors : Array[UpgradeGraph] = []


func _init() -> void:
	for n in predecessors:
		n.is_being_stripped.connect(force_strip)


func check_preconditions() -> bool:
	return check_preconditions() and predecessors.all(func(n): return n.check_preconditions())


## Unapplies this upgrade.
## If accumulation will be 0 after the function ends,
## then calls force_strip on every upgrade that depends on this upgrade also
## Successors are unapplied before this.
func remove_upgrade() -> void:
	if accumulation == 1:
		is_being_stripped.emit()
	super.remove_upgrade()


func force_strip() -> void:
	for i in accumulation:		# TODO: needs testing on accumulation
		remove_upgrade()