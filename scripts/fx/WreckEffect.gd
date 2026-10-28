extends AbstractEffect
class_name WreckEffect

const GRAVITY: float = 9.81
const AIR_DRAG: float = 0.25
const MOMENTUM_KEPT: float = 0.6
const MAX_FALL_TIME: float = 30.0
const TRAIL_PUFFS_PER_SECOND: float = 34.0
const TRAIL_SPREAD: float = 2.0
const TRAIL_PUFF_SCALE: float = 0.7
const EMBERS_PER_SECOND: float = 14.0
const EMBER_SPEED := Vector2(3.0, 12.0)

var _position: Vector3
var _velocity: Vector3
var _size: float
var _trail := EmissionRate.new()
var _sparks := EmissionRate.new()


func _init(at: Vector3, velocity: Vector3, size: float) -> void:
	_position = at
	_velocity = velocity * MOMENTUM_KEPT
	_size = size


func _on_spawn(_effects: EffectManager) -> void:
	pass


func _on_step(effects: EffectManager, delta: float) -> void:
	_fall(delta)
	_trail_smoke(effects, delta)
	if _position.y <= effects.sea_level():
		_hit_water(effects)
	elif age >= MAX_FALL_TIME:
		finish()


func _fall(delta: float) -> void:
	_velocity.y -= GRAVITY * delta
	_velocity -= _velocity * clampf(AIR_DRAG * delta, 0.0, 1.0)
	_position += _velocity * delta


func _trail_smoke(effects: EffectManager, delta: float) -> void:
	for index in _trail.due(TRAIL_PUFFS_PER_SECOND, delta):
		effects.fireballs.emit(
			_position, ParticleBatch.random_direction() * TRAIL_SPREAD, _size * TRAIL_PUFF_SCALE
		)
	for index in _sparks.due(EMBERS_PER_SECOND, delta):
		effects.embers.emit(
			_position, ParticleBatch.random_direction() * randf_range(EMBER_SPEED.x, EMBER_SPEED.y)
		)


func _hit_water(effects: EffectManager) -> void:
	var surface := Vector3(_position.x, effects.sea_level(), _position.z)
	effects.splash(surface, _size)
	effects.spawn(SurfaceFireEffect.new(surface, _size))
	finish()
