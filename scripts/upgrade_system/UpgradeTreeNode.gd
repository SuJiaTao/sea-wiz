## Represents a node of a non-backtracking graph representing an "upgrade tree".[br]
## Intended for displaying or getting next available upgrades in an upgrade tree.[br]
## Note: This does not extend Upgrade.
extends RefCounted
class_name UpgradeTreeNode


var stored_upgrade : UpgradeGraph
var successors: Array[UpgradeTreeNode] = []
var predecessors: Array[UpgradeTreeNode] = []
var tree_tag : int = -1

class UpgradeList:
	var list: Array[UpgradeGraph] = []

static var _next_tag : int = 0
static var _upgrades_dict : Dictionary[int, UpgradeList]

## Returns a new orphan UpgradeTreeNode.[br]
## Use build_tree(UpgradeGraph) if you want the tree.
func _init(upgrade: UpgradeGraph) -> void:
	stored_upgrade = upgrade 


## Creates and returns an upgrade tree structure that contains upgrade_tail. [br]
## Returned upgrade tree will not include successors are on the same depth or more than upgrade_tail.
static func build_tree(upgrade_tail: UpgradeGraph) -> UpgradeTreeNode:
	_upgrades_dict.set(_next_tag, UpgradeList.new())
	var tree_head := UpgradeTreeNode.new(upgrade_tail)
	var root = _build_tree_helper(tree_head)
	_next_tag += 1
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
		_upgrades_dict.get(_next_tag).list.push_back(child.stored_upgrade)
		child.tree_tag = _next_tag
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


## Disconnects node from its tree
func disconnect_from_tree() -> void:
	for s in successors:
		s.predecessors.erase(self)
	for p in predecessors:
		p.successors.erase(self)
	successors = []
	predecessors = []


## Grafts given tree to this tree node. Does nothing if given tree's nodes' upgrades are not part of the upgrade tree.
## Discards any node that this tree already has
func graft_tree(tree: UpgradeTreeNode) -> void:
	bfs(tree, _graft_helper)

func _graft_helper(node: UpgradeTreeNode) -> void:
	if has_upgrade(node.stored_upgrade):
		node.disconnect_from_tree()
		return
	node.tree_tag = tree_tag
	_upgrades_dict.get(tree_tag).list.push_back(node.stored_upgrade)
	bfs(self, _graft_node.bind(node))



func _graft_node(node: UpgradeTreeNode, scion: UpgradeTreeNode) -> void:
	if scion.stored_upgrade.predecessors.has(node.stored_upgrade):
		scion.predecessors.push_back(node)
		node.successors.push_back(scion)
	elif node.stored_upgrade.predecessors.has(scion.stored_upgrade):
		scion.successors.push_back(node)
		node.predecessors.push_back(scion)


## Returns the node in this upgrade tree containting upgrade. Returns null if not found
func get_upgrade_node_of(upgrade: UpgradeGraph) -> UpgradeTreeNode:
	var visited = []
	var next = []
	next.append(self)
	while not next.is_empty():
		var curr : UpgradeTreeNode = next.pop_front()
		if visited.has(curr):
			continue
		next.append_array(curr.successors)
		next.append_array(curr.predecessors)

		visited.append(curr)
		if (curr.stored_upgrade == upgrade):
			return curr
	
	return null


func get_upgrades() -> Array[UpgradeGraph]:
	return _upgrades_dict.get(tree_tag).list


func has_upgrade(upgrade: UpgradeGraph) -> bool:
	return get_upgrades().has(upgrade)
	