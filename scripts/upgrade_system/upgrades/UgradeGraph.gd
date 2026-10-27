## A class graph representing an "upgrade tree", the graph flows backwards with no backtracks, starting from the end of an upgrade tree.
@abstract
class_name UpgradeGraph
extends Upgrade

signal is_being_stripped

@export var predecessors : Array[UpgradeGraph] = []


func setup() -> void:
	for n in predecessors:
		n.is_being_stripped.connect(force_strip)


func is_applied() -> bool:
	return super.is_applied() and predecessors.all(func(n): return n.is_applied())


func check_preconditions() -> bool:
	var flag : bool = super.check_preconditions()
	flag = flag and predecessors.all(func(n): return n.is_applied())
	return flag


## Unapplies this upgrade.
## If accumulation will be 0 after the function ends,
## then calls force_strip on every upgrade that depends on this upgrade also
## Successors are unapplied before this.
func strip_upgrade() -> void:
	if accumulation == 1:
		is_being_stripped.emit()
	super.strip_upgrade()


func force_strip() -> void:
	for i in accumulation:
		strip_upgrade()
