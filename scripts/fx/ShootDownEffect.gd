extends AbstractEffect
class_name ShootDownEffect

const REFERENCE_RADIUS: float = 5.0
const MIN_SIZE: float = 0.4
const MAX_SIZE: float = 4.0

var _position: Vector3
var _velocity: Vector3
var _size: float


func _init(at: Vector3, velocity: Vector3, radius: float) -> void:
	_position = at
	_velocity = velocity
	_size = clampf(radius / REFERENCE_RADIUS, MIN_SIZE, MAX_SIZE)


func _on_spawn(effects: EffectManager) -> void:
	effects.spawn(ExplosionEffect.new(_position, _velocity, _size))
	effects.spawn(WreckEffect.new(_position, _velocity, _size))
	finish()
