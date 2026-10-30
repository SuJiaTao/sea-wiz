extends Node

var a1 : UpgradeGraph = load("res://scripts/upgrade_system/upgrades/resources/test resources/Htree/A1_test-node.tres")
var a2 : UpgradeGraph = load("res://scripts/upgrade_system/upgrades/resources/test resources/Htree/A2_test-node.tres")
var b1 : UpgradeGraph = load("res://scripts/upgrade_system/upgrades/resources/test resources/Htree/B1_test-node.tres")
var b2 : UpgradeGraph = load("res://scripts/upgrade_system/upgrades/resources/test resources/Htree/B2_test-node.tres")
var c1 : UpgradeGraph = load("res://scripts/upgrade_system/upgrades/resources/test resources/Htree/C1_test-node.tres")
var c2 : UpgradeGraph = load("res://scripts/upgrade_system/upgrades/resources/test resources/Htree/C2_test-node.tres")
var d1 : UpgradeGraph = load("res://scripts/upgrade_system/upgrades/resources/test resources/Htree/D1_test-node.tres")
var d2 : UpgradeGraph = load("res://scripts/upgrade_system/upgrades/resources/test resources/Htree/D2_test-node.tres")
var e1 : UpgradeGraph = load("res://scripts/upgrade_system/upgrades/resources/test resources/Htree/E1_test-node.tres")

var upgrade_tree : UpgradeTreeNode


func _ready() -> void:
	upgrade_tree = UpgradeTreeNode.build_tree(e1)
	var res = upgrade_tree.get_upgrade_node_of(c2)
	upgrade_tree.graft_tree(UpgradeTreeNode.build_tree(d1))
	display_tree(res)
	print(res.get_upgrades().map(func(u): return u.label))


func display_tree(tree: UpgradeTreeNode) -> void:
	UpgradeTreeNode.bfs(tree, func(x): print(x.stored_upgrade.label))
