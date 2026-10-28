## Must call build_trees() before use if any given upgrade is an UpgradeGraph
class_name UpgradeProvider
extends Resource

static var rng := RandomNumberGenerator.new()

@export var _upgrades : Array[Upgrade]
var _pool : Array[Upgrade]
var _unavailable_upgardes : Array[Upgrade]


func build_trees() -> void:
	for u in _upgrades:
		if u is UpgradeGraph:
			u.setup()


func reset_pool() -> void:
	_pool.clear()
	_unavailable_upgardes.clear()
	for upgrade in _upgrades:
		if upgrade.check_preconditions():
			_pool.append(upgrade)
		elif not upgrade.is_applied():
			_unavailable_upgardes.append(upgrade)


func _get_pool() -> Array[Upgrade]:
	reset_pool()
	return _pool.duplicate()


func get_unavailable_upgrades() -> Array[Upgrade]:
	return _unavailable_upgardes


## NOTE: Duplicate array before passing to pool if you want to keep the original array unaffected
func _process_upgrade_array(new_pool: Array[Upgrade], count: int) -> Array[Upgrade]:
	new_pool = new_pool.slice(0, min(new_pool.size(), count))
	return new_pool


func get_new_upgrades(count: int)  -> Array[Upgrade]:
	var new_pool : Array[Upgrade] = _get_pool()
	return _process_upgrade_array(new_pool, count)


func get_new_upgrades_of_category(count: int, category: String) -> Array[Upgrade]:
	var filtered : Array[Upgrade] = _get_pool()
	filtered = filtered.filter(func(u: Upgrade): return (u.category == category))
	return _process_upgrade_array(filtered, count)


func get_new_upgrades_weighted(count: int) -> Array[Upgrade]:
	var new_pool : Array[Upgrade] = _get_pool()

	var weights_array : Array[float]
	for u in new_pool:
		weights_array.append(u.weight)
	var grab_order : Array[int] = _weighted_grab(weights_array, min(weights_array.size(), count))
	var shuffled_pool : Array[Upgrade]
	for index in grab_order:
		shuffled_pool.append(new_pool[index])

	return _process_upgrade_array(shuffled_pool, count)


class WeightIndexPair:
	var weight : float
	var index  : int
	func _init(new_weight: float, new_index: int) -> void:
		weight = new_weight
		index = new_index


## weights is an array of weights
## generates an array of size count of integers from the given array.
## the resulting array elements are grabbed without replacing from the given array
## based on the weights.
## result_size is assumed to be <= weights.size()
func _weighted_grab(weights: Array[float], result_size: int) -> Array[int]:
	var wi_pool : Array[WeightIndexPair]
	for j in weights.size():
		wi_pool.push_back(WeightIndexPair.new(weights.get(j), j))

	var result : Array[int]
	for i in range(result_size):
		var weight_pool : Array[float]
		for wi in wi_pool:
			weight_pool.push_back(wi.weight)

		var chosen_pair : WeightIndexPair = wi_pool[rng.rand_weighted(weight_pool)]
		result.push_back(chosen_pair.index)
		wi_pool.erase(chosen_pair)

	return result
