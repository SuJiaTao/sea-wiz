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
@export var salvos: int = 2
## Flares go out in pairs, one from each side, one pair after another, so the
## trail fans out behind the jet like a pair of wings.
@export var pair_interval: float = 0.09
@export_range(0.0, 1.0) var side_throw: float = 0.75
@export var dispenser_offset: float = 1.5
@export var side_speed := Vector2(28.0, 40.0)

var _ready_in: float = 0.0
var _salvos_left: int = 0
var _salvo: Array[DecoyFlare] = []
var _pairs_left: int = 0
var _pair_clock: float = 0.0


func _ready() -> void:
	_salvos_left = salvos


func add_salvos(count: int) -> void:
	_salvos_left += count


func respond_to_missile(origin: Vector3, carrier_velocity: Vector3) -> DecoyFlare:
	if _ready_in <= 0.0 and _salvos_left > 0:
		_release(origin, carrier_velocity)
		return _pick_burning(seduce_chance)
	return _pick_burning(lingering_seduce_chance)


func _process(delta: float) -> void:
	_ready_in = maxf(_ready_in - delta, 0.0)
	if _pairs_left <= 0:
		return
	_pair_clock -= delta
	if _pair_clock > 0.0:
		return
	var carrier := get_parent() as AbstractEnemy
	if not is_instance_valid(carrier) or not carrier.alive:
		_pairs_left = 0
		return
	_release_pair(carrier.global_position, carrier.velocity)


func _release(origin: Vector3, carrier_velocity: Vector3) -> void:
	_salvo = []
	_pairs_left = maxi(flares_per_salvo / 2, 1)
	_ready_in = cooldown
	_salvos_left -= 1
	_release_pair(origin, carrier_velocity)


func _release_pair(origin: Vector3, carrier_velocity: Vector3) -> void:
	_pairs_left -= 1
	_pair_clock = pair_interval
	var side := carrier_velocity.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.5:
		side = Vector3.RIGHT
	var pair: Array[DecoyFlare] = []
	for flank: float in [-1.0, 1.0]:
		var throw := (side * flank * side_throw + Vector3.UP * (1.0 - side_throw)).normalized()
		var launch := carrier_velocity * carrier_momentum + throw * randf_range(side_speed.x, side_speed.y)
		var flare := DecoyFlare.new(origin + side * flank * dispenser_offset, launch, drag, randf_range(burn_time.x, burn_time.y))
		pair.append(flare)
		_salvo.append(flare)
	released.emit(pair)


func _pick_burning(chance: float) -> DecoyFlare:
	var lit := _salvo.filter(func(flare: DecoyFlare) -> bool: return flare.burning)
	if lit.is_empty() or randf() >= chance:
		return null
	return lit.pick_random()
