extends Node
class_name BattleEffects

# The big set pieces: fires breaking out on enemy ships as they are hit, ships
# sinking once beaten, and motherships tearing open the sky as they arrive.

const SHIP_FINAL_FIRE: float = 1.0
const WARP_HEAT: float = 0.5
const WARP_DOME_SHARE: float = 0.35

@export var enemies: EnemyManager
@export var effects: EffectManager
@export var thermal: ThermalView


func _ready() -> void:
	enemies.enemy_created.connect(_on_enemy_created)
	enemies.enemy_killed.connect(_on_enemy_killed)


func _on_enemy_created(enemy: AbstractEnemy) -> void:
	if enemy is SurfaceShipEnemy:
		(enemy as SurfaceShipEnemy).fire_started.connect(_on_ship_fire)
	elif enemy is MothershipEnemy:
		(enemy as MothershipEnemy).warped_in.connect(_on_warped_in)


func _on_ship_fire(spot: Node3D, strength: float) -> void:
	effects.spawn(DeckFireEffect.new(spot, strength))


func _on_warped_in(at: Vector3, size: float) -> void:
	effects.spawn(ShockDomeEffect.new(at, size * WARP_DOME_SHARE))
	thermal.heat_burst(WARP_HEAT)


func _on_enemy_killed(enemy: AbstractEnemy, _weapon_source: DamageSource) -> void:
	var ship := enemy as SurfaceShipEnemy
	if ship == null:
		return
	var spots := ship.burning_spots()
	var hull := ship.detach_visuals()
	if not effects.spawn(SinkingShipEffect.new(hull)):
		hull.queue_free()
		return
	for spot in spots:
		effects.spawn(DeckFireEffect.new(spot, SHIP_FINAL_FIRE))
