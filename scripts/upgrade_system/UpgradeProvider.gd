class_name UpgradeProvider
extends Resource

@export var _upgrades : Array[Upgrade]


## NOTE: Duplicate array before passing to pool if you want to keep the original array unaffected
func _process_upgrade_array(pool: Array[Upgrade], count: int) -> Array[Upgrade]:
	pool.shuffle()
	pool = pool.slice(0, min(pool.size(), count))
	return pool


func get_new_upgrades(count: int)  -> Array[Upgrade]:
	var pool = _upgrades.duplicate()
	return _process_upgrade_array(pool, count)


func get_new_upgrades_of_category(count: int, category: String) -> Array[Upgrade]:
	var filtered : Array[Upgrade] = _upgrades.duplicate()
	filtered = filtered.filter(func(u: Upgrade): return (u.category == category))
	return _process_upgrade_array(filtered, count)

