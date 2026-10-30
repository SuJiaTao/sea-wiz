## Represents a node of a non-backtracking graph representing an "upgrade tree".
## Intended for displaying or getting next available upgrades in an upgrade tree.
## Note: This does not extend Upgrade.
extends RefCounted
class_name UpgradeTreeNode


var stored_upgrade : UpgradeGraph
var successors: Array[UpgradeTreeNode] = []
var predecessors: Array[UpgradeTreeNode] = []


## Returns a new orphan UpgradeTreeNode.
## Use build_tree(UpgradeGraph) if you want the tree.
func _init(upgrade: UpgradeGraph) -> void:
	stored_upgrade = upgrade 


## Returns the heads of the upgrade tree that ends with upgrade_tail.
## Returned upgrade tree will not include nodes that are on the same depth or more than upgrade_tail.
static func build_tree(upgrade_tail: UpgradeGraph) -> Array[UpgradeTreeNode]:
	var tree_head := UpgradeTreeNode.new(upgrade_tail)
	var roots = _build_tree_helper(tree_head)
	return roots


static func _create_parents(upgrade: UpgradeGraph) -> Array[UpgradeTreeNode]:
	var result : Array[UpgradeTreeNode] = []
	for parent in upgrade.predecessors:
		result.push_back(UpgradeTreeNode.new(parent))
	
	return result


static func _build_tree_helper(tree: UpgradeTreeNode) -> Array[UpgradeTreeNode]:
	var roots : Array[UpgradeTreeNode] = []
	var next_nodes : Array[UpgradeTreeNode] = []
	next_nodes.push_back(tree)
	while not next_nodes.is_empty():
		var child : UpgradeTreeNode = next_nodes.pop_front()
		var parents : Array[UpgradeTreeNode] = _create_parents(child.stored_upgrade)
		if parents.is_empty():
			roots.push_back(child)
		else:
			child.predecessors = parents
			for p in parents:
				p.successors.push_back(child)

		next_nodes.append_array(parents)
			
	return roots
		

func merge_tree(tree: UpgradeTreeNode) -> void:
	pass