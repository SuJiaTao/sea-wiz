class_name UpgradeProvider
extends Resource

@export var _upgrades : Array[Upgrade]
var _pool : Array[Upgrade]
	

func reset_pool() -> void:
	_pool.clear()
	for upgrade in _upgrades:
		if upgrade.check_preconditions():
			_pool.append(upgrade)

func _get_pool() -> Array[Upgrade]:
	reset_pool()
	return _pool

## NOTE: Duplicate array before passing to pool if you want to keep the original array unaffected
func _process_upgrade_array(new_pool: Array[Upgrade], count: int) -> Array[Upgrade]:
	new_pool.shuffle()
	new_pool = new_pool.slice(0, min(new_pool.size(), count))
	return new_pool


func get_new_upgrades(count: int)  -> Array[Upgrade]:
	var new_pool = _get_pool().duplicate()
	return _process_upgrade_array(new_pool, count)


func get_new_upgrades_of_category(count: int, category: String) -> Array[Upgrade]:
	var filtered : Array[Upgrade] = _get_pool().duplicate()
	filtered = filtered.filter(func(u: Upgrade): return (u.category == category))
	return _process_upgrade_array(filtered, count)



