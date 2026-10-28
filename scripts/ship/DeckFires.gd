extends Node
class_name DeckFires

@export var integrity: ShipIntegrity
@export var effects: EffectManager
@export var spots: Node3D
@export var ignite_strength: float = 0.45
@export var strength_per_damage: float = 0.06

var _burning: Dictionary[Node3D, DeckFireEffect] = {}


func _ready() -> void:
	integrity.damaged.connect(_on_damaged)


func _on_damaged(amount: float, from_position: Vector3) -> void:
	var spot := _spot_facing(from_position)
	if spot == null:
		return
	var added := amount * strength_per_damage
	if _burning.has(spot):
		_burning[spot].grow(added)
		return
	var fire := DeckFireEffect.new(spot, ignite_strength + added)
	if effects.spawn(fire):
		_burning[spot] = fire


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
