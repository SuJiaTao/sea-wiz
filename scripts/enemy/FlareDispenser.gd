extends Node
class_name FlareDispenser

signal released(flares: Array[DecoyFlare])

@export var flares_per_salvo: int = 6
@export var cooldown: float = 5.0
@export_range(0.0, 1.0) var seduce_chance: float = 0.55
@export_range(0.0, 1.0) var lingering_seduce_chance: float = 0.3
@export var eject_speed := Vector2(10.0, 22.0)
@export var carrier_momentum: float = 0.5
@export var drag: float = 1.2
@export var burn_time := Vector2(2.5, 3.5)

var _ready_in: float = 0.0
var _salvo: Array[DecoyFlare] = []


func respond_to_missile(origin: Vector3, carrier_velocity: Vector3) -> DecoyFlare:
	if _ready_in <= 0.0:
		_release(origin, carrier_velocity)
		return _pick_burning(seduce_chance)
	return _pick_burning(lingering_seduce_chance)


func _process(delta: float) -> void:
	_ready_in = maxf(_ready_in - delta, 0.0)


func _release(origin: Vector3, carrier_velocity: Vector3) -> void:
	_salvo = []
	for index in flares_per_salvo:
		var throw := (Vector3.DOWN + ParticleBatch.random_direction()).normalized()
		var launch := carrier_velocity * carrier_momentum + throw * randf_range(eject_speed.x, eject_speed.y)
		_salvo.append(DecoyFlare.new(origin, launch, drag, randf_range(burn_time.x, burn_time.y)))
	_ready_in = cooldown
	released.emit(_salvo.duplicate())


func _pick_burning(chance: float) -> DecoyFlare:
	var lit := _salvo.filter(func(flare: DecoyFlare) -> bool: return flare.burning)
	if lit.is_empty() or randf() >= chance:
		return null
	return lit.pick_random()
