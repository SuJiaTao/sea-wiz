## Must call build_trees() before use if any given upgrade is an UpgradeGraph
class_name UpgradeProvider
extends Resource

static var rng := RandomNumberGenerator.new()

@export var _upgrades : Array[Upgrade]
## _pool is array of upgrades with passing preconditions
var _pool : Array[Upgrade]
var _unavailable_upgardes : Array[Upgrade]


func build_trees() -> void:
	for u in _upgrades:
		if u is UpgradeGraph:
			u.setup()


func _reset_pool() -> void:
	_pool.clear()
	_unavailable_upgardes.clear()
	for upgrade in _upgrades:
		if upgrade.check_preconditions():
			_pool.append(upgrade)
		elif not upgrade.is_applied():
			_unavailable_upgardes.append(upgrade)


## Calls _reset_pool then returns a duplicated _pool
func _get_pool() -> Array[Upgrade]:
	_reset_pool()
	return _pool.duplicate()


## NOTE: Duplicate array before passing to pool if you want to keep the original array unaffected
func _process_upgrade_array(new_pool: Array[Upgrade], count: int) -> Array[Upgrade]:
	new_pool = new_pool.slice(0, min(new_pool.size(), count))
	_sort_pool(new_pool)
	return new_pool


## Returns array of upgrades that did not have passing preconditions
func get_unavailable_upgrades() -> Array[Upgrade]:
	return _unavailable_upgardes


func get_new_upgrades()  -> Array[Upgrade]:
	var new_pool : Array[Upgrade] = _get_pool()
	return _process_upgrade_array(new_pool, -1)


func get_new_upgrades_of_category(category: String) -> Array[Upgrade]:
	var filtered : Array[Upgrade] = _get_pool()
	filtered = filtered.filter(func(u: Upgrade): return (u.category == category))
	return _process_upgrade_array(filtered, -1)


func get_random_upgrades_weighted(count: int) -> Array[Upgrade]:
	var new_pool : Array[Upgrade] = _get_pool()
	if count < 0:
		count = new_pool.size()

	var weights_array : Array[float]
	for u in new_pool:
		weights_array.append(u.weight)
	var grab_order : Array[int] = _weighted_grab(weights_array, min(weights_array.size(), count))
	var shuffled_pool : Array[Upgrade]
	for index in grab_order:
		shuffled_pool.append(new_pool[index])

	return _process_upgrade_array(shuffled_pool, count)

func get_random_upgrades(count: int) -> Array[Upgrade]:
	var new_pool : Array[Upgrade] = _get_pool()
	if count < 0:
		count = new_pool.size()

	new_pool.shuffle()

	return _process_upgrade_array(new_pool, count)

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


## Sorts upgrade pool by its index in upgrades
func _sort_pool(pool: Array[Upgrade]) -> void:
	pool.sort_custom(func(a, b): return _upgrades.find(a) < _upgrades.find(b))

