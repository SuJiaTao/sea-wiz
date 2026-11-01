extends AbstractEffect
class_name NearMissEffect

const COLUMN_TIME: float = 0.45
const COLUMN_PUFFS_PER_SECOND: float = 140.0
const COLUMN_SPEED := Vector2(45.0, 85.0)
const COLUMN_SPREAD: float = 0.07
const COLUMN_PUFF_SCALE: float = 3.6
const COLUMN_LIFE_SCALE: float = 2.2
const SKIRT_PUFFS: int = 36
const SKIRT_SPEED := Vector2(7.0, 15.0)
const SKIRT_LIFT: float = 0.35
const SKIRT_PUFF_SCALE: float = 2.6
const DROPLETS: int = 110
const DROPLET_SPEED := Vector2(18.0, 48.0)
const DROPLET_SPREAD: float = 0.45
const DROPLET_SCALE: float = 2.0
const RIPPLE_SCALE: float = 7.0
const RIPPLE_LIFT: float = 0.08
const BLAST_SCALE: float = 1.1

var _position: Vector3
var _size: float
var _column := EmissionRate.new()


func _init(at: Vector3, size: float) -> void:
	_position = at
	_size = size


func _on_spawn(effects: EffectManager) -> void:
	effects.spawn(ExplosionEffect.new(_position, Vector3.ZERO, _size * BLAST_SCALE))
	_throw_skirt(effects)
	_throw_droplets(effects)
	effects.ripples.emit(_position + Vector3.UP * RIPPLE_LIFT, Vector3.ZERO, _size * RIPPLE_SCALE)


func _on_step(effects: EffectManager, delta: float) -> void:
	for index in _column.due(COLUMN_PUFFS_PER_SECOND * _size, delta):
		effects.spray.emit(
			_position, _upward(COLUMN_SPREAD) * randf_range(COLUMN_SPEED.x, COLUMN_SPEED.y),
			_size * COLUMN_PUFF_SCALE, COLUMN_LIFE_SCALE
		)
	if age >= COLUMN_TIME:
		finish()


func _throw_skirt(effects: EffectManager) -> void:
	for index in SKIRT_PUFFS:
		var outward := ParticleBatch.random_direction()
		outward = Vector3(outward.x, absf(outward.y) * SKIRT_LIFT, outward.z).normalized()
		effects.spray.emit(
			_position, outward * randf_range(SKIRT_SPEED.x, SKIRT_SPEED.y), _size * SKIRT_PUFF_SCALE
		)


func _throw_droplets(effects: EffectManager) -> void:
	for index in DROPLETS:
		effects.droplets.emit(
			_position, _upward(DROPLET_SPREAD) * randf_range(DROPLET_SPEED.x, DROPLET_SPEED.y),
			_size * DROPLET_SCALE
		)


func _upward(spread: float) -> Vector3:
	return Vector3(randfn(0.0, spread), 1.0, randfn(0.0, spread)).normalized()
