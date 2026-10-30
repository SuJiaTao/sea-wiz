extends Node

@export var ugprade : UpgradeGraph
@export var c2 : UpgradeGraph

var upgrade_tree : UpgradeTreeNode


func _ready() -> void:
	upgrade_tree = UpgradeTreeNode.build_tree(ugprade)
	var res = upgrade_tree.get_upgrade_node_of(c2)
	display_tree(res)


func display_tree(tree: UpgradeTreeNode) -> void:
	UpgradeTreeNode.bfs(tree, func(x): print(x.stored_upgrade.label))
