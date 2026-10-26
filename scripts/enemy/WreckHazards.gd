extends Node
class_name WreckHazards

const TARGET_ATTEMPTS: int = 6

@export var effects: EffectManager
@export var enemies: EnemyManager
@export var wreck_scene: PackedScene
@export var hazard_radius: float = 60.0
@export var steer_reach: float = 500.0
@export_range(0.0, 1.0) var steer_chance: float = 0.5
@export var max_steer_change: float = 70.0
@export var deck_spread: float = 40.0


func _ready() -> void:
	effects.wreck_falling.connect(_on_wreck_falling)


func _on_wreck_falling(wreck: WreckEffect) -> void:
	var ship := enemies.global_position
	var target := _deck_target(ship)
	var floor_height := effects.deck_height_at(target)
	if is_nan(floor_height):
		return
	if not _should_threaten(wreck.predicted_landing(floor_height), ship):
		return
	if not wreck.steer_to(target, floor_height, max_steer_change):
		return
	var hazard := wreck_scene.instantiate() as WreckEnemy
	hazard.follow(wreck, ship)
	if not enemies.create(hazard, Transform3D(Basis.IDENTITY, wreck.position)):
		hazard.free()


func _should_threaten(landing: Vector3, ship: Vector3) -> bool:
	var miss := _flat_distance(landing, ship)
	if miss > steer_reach:
		return false
	return miss <= hazard_radius or randf() <= steer_chance


func _deck_target(ship: Vector3) -> Vector3:
	for attempt in TARGET_ATTEMPTS:
		var spot := ship + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * deck_spread
		if not is_nan(effects.deck_height_at(spot)):
			return spot
	return ship


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
