extends AbstractEffect
class_name SmokeColumnEffect

const DURATION: float = 4.5
const PUFFS_PER_SECOND: float = 24.0
const RISE := Vector2(8.0, 16.0)
const SPREAD: float = 0.35
const PUFF_SCALE: float = 3.2
const LIFE_SCALE: float = 1.5

var _position: Vector3
var _size: float
var _puffs := EmissionRate.new()


func _init(at: Vector3, size: float) -> void:
	_position = at
	_size = size


func _on_spawn(_effects: EffectManager) -> void:
	pass


func _on_step(effects: EffectManager, delta: float) -> void:
	var easing := 1.0 - age / DURATION
	for index in _puffs.due(PUFFS_PER_SECOND * easing, delta):
		var drift := Vector3(randfn(0.0, SPREAD), 1.0, randfn(0.0, SPREAD)).normalized()
		effects.smoke.emit(
			_position, drift * randf_range(RISE.x, RISE.y) * sqrt(_size), _size * PUFF_SCALE, LIFE_SCALE
		)
	if age >= DURATION:
		finish()
