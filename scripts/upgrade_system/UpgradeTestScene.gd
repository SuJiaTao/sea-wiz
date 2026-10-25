extends Node

@export var provider : UpgradeProvider

func _ready() -> void:
	print_result(provider.get_new_upgrades(3))
	print_result(provider.get_new_upgrades(4))
	print_result(provider.get_new_upgrades(10))
	print_result(provider.get_new_upgrades_of_category(2, "Default"))
	print_result(provider.get_new_upgrades_of_category(3, "TestCat"))
	print_result(provider.get_new_upgrades_of_category(10, "TestCat"))

func print_result(array: Array[Upgrade]) -> void:
	var label_array : Array = array.map(func(u: Upgrade): return u.label)
	print(label_array)