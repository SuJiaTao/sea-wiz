## Represents a node of a non-backtracking graph representing an "upgrade tree".[br]
## Intended for displaying or getting next available upgrades in an upgrade tree.[br]
## Note: This does not extend Upgrade.
extends RefCounted
class_name UpgradeTreeNode


var stored_upgrade : UpgradeGraph
var successors: Array[UpgradeTreeNode] = []
var predecessors: Array[UpgradeTreeNode] = []


## Returns a new orphan UpgradeTreeNode.[br]
## Use build_tree(UpgradeGraph) if you want the tree.
func _init(upgrade: UpgradeGraph) -> void:
	stored_upgrade = upgrade 


## Creates and returns an upgrade tree structure that contains upgrade_tail. [br]
## Returned upgrade tree will not include successors are on the same depth or more than upgrade_tail.
static func build_tree(upgrade_tail: UpgradeGraph) -> UpgradeTreeNode:
	var tree_head := UpgradeTreeNode.new(upgrade_tail)
	var root = _build_tree_helper(tree_head)
	return root


static func _create_parents(upgrade: UpgradeGraph) -> Array[UpgradeTreeNode]:
	var result : Array[UpgradeTreeNode] = []
	for parent in upgrade.predecessors:
		result.push_back(UpgradeTreeNode.new(parent))
	
	return result


static func _build_tree_helper(tree: UpgradeTreeNode) -> UpgradeTreeNode:
	var next_nodes : Array[UpgradeTreeNode] = []
	next_nodes.push_back(tree)
	while not next_nodes.is_empty():
		var child : UpgradeTreeNode = next_nodes.pop_front()
		var parents : Array[UpgradeTreeNode] = _create_parents(child.stored_upgrade)
		child.predecessors = parents
		for p in parents:
			p.successors.push_back(child)

		next_nodes.append_array(parents)
			
	return tree
		

## graph: any part of an upgrade tree[br]
## on_visit: in the format func(x: UpgradeTreeNode)
static func bfs(graph: UpgradeTreeNode, on_visit: Callable) -> void:
	var visited = []
	var next = []
	next.append(graph)
	while not next.is_empty():
		var curr : UpgradeTreeNode = next.pop_front()
		if visited.has(curr):
			continue
		next.append_array(curr.successors)
		next.append_array(curr.predecessors)

		visited.append(curr)
		on_visit.call(curr)


func merge_tree(tree: UpgradeTreeNode) -> void:
	pass

var _result : UpgradeTreeNode
func get_upgrade_node_of(upgrade: UpgradeGraph) -> UpgradeTreeNode:
	bfs(self, func(x): if x.stored_upgrade == upgrade: _result = x)
	return _result
