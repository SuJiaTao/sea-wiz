extends Node
class_name DeckFires

## In a downpour a full fire dies out in a few seconds.
const RAIN_DOUSE_PER_SECOND: float = 0.3
## Only the few worst fires cast light, which is plenty to sell it and cheap.
const LIGHTS: int = 4
const LIGHT_COLOUR := Color(1.0, 0.55, 0.2)
const LIGHT_ENERGY: float = 6.0
const LIGHT_RANGE: float = 22.0
const LIGHT_LIFT: float = 3.0
## Firelight flickers: a fast random jitter over a slower swell.
const FLICKER_DEPTH: float = 0.35
const SWELL_RATE: float = 3.0

@export var integrity: ShipIntegrity
@export var effects: EffectManager
@export var spots: Node3D
@export var ignite_strength: float = 0.45
@export var strength_per_damage: float = 0.06
@export var impact_blast: float = 0.6

var _burning: Dictionary[Node3D, DeckFireEffect] = {}
var _lights: Array[OmniLight3D] = []
var _clock: float = 0.0


func _ready() -> void:
	integrity.damaged.connect(_on_damaged)
	integrity.repaired.connect(_on_repaired)
	for index in LIGHTS:
		var light := OmniLight3D.new()
		light.light_color = LIGHT_COLOUR
		light.omni_range = LIGHT_RANGE
		light.shadow_enabled = false
		light.visible = false
		spots.add_child(light)
		_lights.append(light)


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
	_clock += delta
	_light_worst_fires()
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


func _light_worst_fires() -> void:
	var fires: Array[DeckFireEffect] = []
	for fire in _burning.values():
		if fire.strength() > 0.0:
			fires.append(fire)
	fires.sort_custom(func(a: DeckFireEffect, b: DeckFireEffect) -> bool: return a.strength() > b.strength())
	for index in _lights.size():
		var light := _lights[index]
		light.visible = index < fires.size()
		if not light.visible:
			continue
		var fire := fires[index]
		var swell := 0.5 + 0.5 * sin(_clock * SWELL_RATE + index * 1.7)
		var flicker := 1.0 - FLICKER_DEPTH * (randf() * 0.6 + swell * 0.4)
		light.global_position = fire.position() + Vector3.UP * LIGHT_LIFT
		light.light_energy = LIGHT_ENERGY * fire.strength() * flicker
