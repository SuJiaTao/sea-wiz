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
const ROLL_RATE := Vector2(1.5, 4.0)
const MIN_SPEED_SQUARED: float = 0.01
const ROLL_LEFT_CHANCE: float = 0.5
const NEAR_VERTICAL: float = 0.98

var _position: Vector3
var _velocity: Vector3
var _size: float
var _wreckage: Node3D
var _wreckage_scale := Vector3.ONE
var _roll: float = 0.0
var _roll_rate: float
var _trail := EmissionRate.new()
var _sparks := EmissionRate.new()


func _init(at: Vector3, velocity: Vector3, size: float, wreckage: Node3D = null) -> void:
	_position = at
	_velocity = velocity * MOMENTUM_KEPT
	_size = size
	_wreckage = wreckage
	_roll_rate = randf_range(ROLL_RATE.x, ROLL_RATE.y) * (-1.0 if randf() < ROLL_LEFT_CHANCE else 1.0)


func _on_spawn(effects: EffectManager) -> void:
	if _wreckage == null:
		return
	var start := _wreckage.transform
	_wreckage_scale = start.basis.get_scale()
	effects.add_child(_wreckage)
	_wreckage.global_transform = start


func _on_step(effects: EffectManager, delta: float) -> void:
	_fall(delta)
	_tumble(delta)
	_trail_smoke(effects, delta)
	var deck := effects.deck_height_at(_position)
	if not is_nan(deck) and _position.y <= deck:
		_hit_ship(effects)
	elif _position.y <= effects.sea_level():
		_hit_water(effects)
	elif age >= MAX_FALL_TIME:
		finish()


func _on_finish(_effects: EffectManager) -> void:
	if is_instance_valid(_wreckage):
		_wreckage.queue_free()


func _fall(delta: float) -> void:
	_velocity.y -= GRAVITY * delta
	_velocity -= _velocity * clampf(AIR_DRAG * delta, 0.0, 1.0)
	_position += _velocity * delta


func _tumble(delta: float) -> void:
	if not is_instance_valid(_wreckage) or _velocity.length_squared() < MIN_SPEED_SQUARED:
		return
	_roll += _roll_rate * delta
	var heading := _velocity.normalized()
	var up := Vector3.UP if absf(heading.dot(Vector3.UP)) < NEAR_VERTICAL else Vector3.FORWARD
	_wreckage.global_transform = Transform3D(
		Basis.looking_at(heading, up) * Basis(Vector3.FORWARD, _roll) * Basis.from_scale(_wreckage_scale),
		_position
	)


func _trail_smoke(effects: EffectManager, delta: float) -> void:
	for index in _trail.due(TRAIL_PUFFS_PER_SECOND, delta):
		effects.fireballs.emit(
			_position, ParticleBatch.random_direction() * TRAIL_SPREAD, _size * TRAIL_PUFF_SCALE
		)
	for index in _sparks.due(EMBERS_PER_SECOND, delta):
		effects.embers.emit(
			_position, ParticleBatch.random_direction() * randf_range(EMBER_SPEED.x, EMBER_SPEED.y)
		)


func _hit_ship(effects: EffectManager) -> void:
	effects.spawn(ExplosionEffect.new(_position, Vector3.ZERO, _size))
	effects.wreck_hit_ship.emit(_position, _size)
	finish()


func _hit_water(effects: EffectManager) -> void:
	var surface := Vector3(_position.x, effects.sea_level(), _position.z)
	effects.splash(surface, _size)
	effects.spawn(SurfaceFireEffect.new(surface, _size))
	finish()
