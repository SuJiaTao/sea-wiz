extends RefCounted
class_name ChaffScreen
## The chaff clouds hanging off the ship, and which incoming missiles they
## have already pulled away or failed to.

const LURE_RANGE: float = 2600.0
const LURE_CHANCE: float = 0.8

var _clouds: Array[Vector3] = []
var _time_left: float
var _judged: Dictionary[AbstractEnemy, bool] = {}


func _init(clouds: Array[Vector3], lifetime: float) -> void:
	_clouds = clouds
	_time_left = lifetime


func is_active() -> bool:
	return _time_left > 0.0


func age(delta: float) -> void:
	_time_left -= delta


func seduce(enemies: Array[AbstractEnemy], ship: Vector3) -> void:
	for enemy in enemies:
		if enemy.contact_kind != AbstractEnemy.ContactKind.MISSILE or _judged.has(enemy):
			continue
		if enemy.global_position.distance_to(ship) > LURE_RANGE:
			continue
		_judged[enemy] = randf() < LURE_CHANCE and enemy.lure(_nearest(enemy.global_position))


func _nearest(from: Vector3) -> Vector3:
	var best := _clouds[0]
	for cloud in _clouds:
		if from.distance_to(cloud) < from.distance_to(best):
			best = cloud
	return best
