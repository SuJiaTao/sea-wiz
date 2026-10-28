extends AbstractEffect
class_name SmokeStreamerEffect

const GRAVITY: float = 9.81
const DRAG: float = 0.6
const LAUNCH_SPEED := Vector2(35.0, 65.0)
const LIFT: float = 0.6
const BURN_TIME := Vector2(0.9, 1.6)
const PUFFS_PER_SECOND: float = 40.0
const PUFF_SCALE: float = 0.55
const FIRE_SHARE: float = 0.35

var _position: Vector3
var _velocity: Vector3
var _size: float
var _burn_time: float
var _puffs := EmissionRate.new()


func _init(at: Vector3, size: float) -> void:
	_position = at
	_size = size
	var direction := ParticleBatch.random_direction()
	direction.y = absf(direction.y) + LIFT
	_velocity = direction.normalized() * randf_range(LAUNCH_SPEED.x, LAUNCH_SPEED.y) * sqrt(size)
	_burn_time = randf_range(BURN_TIME.x, BURN_TIME.y)


func _on_spawn(_effects: EffectManager) -> void:
	pass


func _on_step(effects: EffectManager, delta: float) -> void:
	_velocity.y -= GRAVITY * delta
	_velocity -= _velocity * clampf(DRAG * delta, 0.0, 1.0)
	_position += _velocity * delta
	var fading := 1.0 - age / _burn_time
	for index in _puffs.due(PUFFS_PER_SECOND, delta):
		var batch := effects.fireballs if age < _burn_time * FIRE_SHARE else effects.smoke
		batch.emit(_position, Vector3.ZERO, _size * PUFF_SCALE * maxf(fading, 0.2))
	if age >= _burn_time:
		finish()
