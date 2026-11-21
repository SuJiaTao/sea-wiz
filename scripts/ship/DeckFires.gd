extends Node
class_name DeckFires

## In a downpour a full fire dies out in a few seconds.
const RAIN_DOUSE_PER_SECOND: float = 0.3

@export var integrity: ShipIntegrity
@export var effects: EffectManager
@export var spots: Node3D
@export var ignite_strength: float = 0.45
@export var strength_per_damage: float = 0.06
@export var impact_blast: float = 0.6

var _burning: Dictionary[Node3D, DeckFireEffect] = {}


func _ready() -> void:
	integrity.damaged.connect(_on_damaged)
	integrity.repaired.connect(_on_repaired)


func _on_damaged(amount: float, from_position: Vector3) -> void:
	var spot := _spot_facing(from_position)
	if spot == null:
		return
	effects.spawn(ExplosionEffect.new(spot.global_position, Vector3.ZERO, impact_blast))
	var added := amount * strength_per_damage
	if _burning.has(spot):
		_burning[spot].grow(added)
		return
	var fire := DeckFireEffect.new(spot, ignite_strength + added)
	if effects.spawn(fire):
		_burning[spot] = fire


## How hard the worst fire on board is burning, 0 when the ship is not on fire.
func blaze() -> float:
	var worst := 0.0
	for fire in _burning.values():
		worst = maxf(worst, fire.strength())
	return worst


func engulf() -> void:
	ignite_all(1.0)


## Sets every spot on the ship burning at least this hard.
func ignite_all(strength: float) -> void:
	for child in spots.get_children():
		var spot := child as Node3D
		if spot == null:
			continue
		if _burning.has(spot):
			_burning[spot].grow(strength)
			continue
		var fire := DeckFireEffect.new(spot, strength)
		if effects.spawn(fire):
			_burning[spot] = fire


func _process(delta: float) -> void:
	if effects.wetness <= 0.0:
		return
	var soaking := maxf(1.0 - RAIN_DOUSE_PER_SECOND * effects.wetness * delta, 0.0)
	for spot in _burning.keys():
		if not _burning[spot].dampen(soaking):
			_burning.erase(spot)


func _on_repaired(damage_left_fraction: float) -> void:
	for spot in _burning.keys():
		if not _burning[spot].dampen(damage_left_fraction):
			_burning.erase(spot)


func _spot_facing(from_position: Vector3) -> Node3D:
	var centre := spots.global_position
	var threat := _flat(from_position - centre)
	var best: Node3D
	var best_score := -INF
	for child in spots.get_children():
		var spot := child as Node3D
		if spot == null:
			continue
		var score := threat.dot(_flat(spot.global_position - centre))
		if not _burning.has(spot):
			score += 2.0
		if score > best_score:
			best = spot
			best_score = score
	return best


func _flat(offset: Vector3) -> Vector3:
	return Vector3(offset.x, 0.0, offset.z).normalized()
