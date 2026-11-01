extends AbstractEffect
class_name ShootDownEffect

const REFERENCE_RADIUS: float = 5.0
const MIN_SIZE: float = 0.4
const MAX_SIZE: float = 4.0
const CRIPPLE_CHANCE: float = 0.5
const CRIPPLED_BLAST_SCALE: float = 0.35

var _position: Vector3
var _velocity: Vector3
var _size: float
var _wreckage: Node3D


func _init(at: Vector3, velocity: Vector3, radius: float, wreckage: Node3D = null) -> void:
	_position = at
	_velocity = velocity
	_size = clampf(radius / REFERENCE_RADIUS, MIN_SIZE, MAX_SIZE)
	_wreckage = wreckage


func _on_spawn(effects: EffectManager) -> void:
	var crippled := randf() < CRIPPLE_CHANCE
	var blast := _size * (CRIPPLED_BLAST_SCALE if crippled else 1.0)
	effects.spawn(ExplosionEffect.new(_position, _velocity, blast))
	effects.spawn(WreckEffect.new(_position, _velocity, _size, _wreckage))
	finish()
