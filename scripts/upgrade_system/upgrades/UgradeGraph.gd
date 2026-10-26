## A class graph representing an "upgrade tree", with preceding	and succeeding upgrades. There are no backtracks.
@abstract
class_name UpgradeGraph
extends Upgrade

@export var predecessors : Array[UpgradeGraph] = []
@export var successors : Array[UpgradeGraph] = []


## Returns true if all necessary conditions and can_accumulate_still() is true, false otherwise
func check_preconditions() -> bool:
	var flag : bool = super.check_preconditions()
	flag = flag && predecessors.all(func(u): return (u.check_preconditions()))
	return flag


## Returns all nodes down the graph that where check_preconditions() is true, excluding this node.
## Returns an empty array if there are no such nodes.
func get_next_upgrades() -> Array[UpgradeGraph]:
	var result : Array[UpgradeGraph] = []
	if check_preconditions():
		result.append(self)
	for upgrade in successors:
		result.append_array(upgrade.get_next_upgrades())
	return result


## Unapplies this upgrade. If accumulation == 0, unapplies every upgrade down the graph as well.
## Successors are unapplied first before this.
func remove_upgrade() -> void:
	for upgrade in successors:
		upgrade.remove_upgrade()
	super.remove_upgrade()