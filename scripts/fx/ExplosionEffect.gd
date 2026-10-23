extends AbstractEffect
class_name ExplosionEffect

const FIREBALL_PUFFS: int = 6
const FIREBALL_PUFFS_PER_SIZE: int = 5
const FIREBALL_SPEED := Vector2(3.0, 9.0)
const EMBERS_PER_SIZE: int = 22
const MAX_EMBERS: int = 90
const EMBER_SPEED := Vector2(12.0, 45.0)
const MOMENTUM_KEPT: float = 0.35

var _position: Vector3
var _velocity: Vector3
var _size: float


func _init(at: Vector3, velocity: Vector3, size: float) -> void:
	_position = at
	_velocity = velocity
	_size = size


func _on_spawn(effects: EffectManager) -> void:
	var carried := _velocity * MOMENTUM_KEPT
	var puffs := FIREBALL_PUFFS + int(FIREBALL_PUFFS_PER_SIZE * _size)
	effects.fireballs.burst(_position, puffs, FIREBALL_SPEED * _size, _size, carried)
	var sparks := mini(int(EMBERS_PER_SIZE * _size), MAX_EMBERS)
	effects.embers.burst(_position, sparks, EMBER_SPEED * sqrt(_size), 1.0, carried)
	finish()
