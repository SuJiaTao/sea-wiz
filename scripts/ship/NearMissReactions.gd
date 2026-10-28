extends Node
class_name NearMissReactions

@export var enemies: EnemyManager
@export var effects: EffectManager
@export var integrity: ShipIntegrity
@export var turret: Turret
@export var lens: LensSpray
@export var blast_size: float = 1.0
@export var felt_radius: float = 280.0
@export var rock_impulse: float = 4.0
@export var shrapnel_radius: float = 120.0
@export var shrapnel_damage: float = 7.0
@export_range(0.0, 1.0) var douse_chance: float = 0.4
@export var douse_amount: float = 8.0


func _ready() -> void:
	enemies.enemy_created.connect(_on_enemy_created)


func _on_enemy_created(enemy: AbstractEnemy) -> void:
	enemy.missed.connect(_on_missed)


func _on_missed(point: Vector3) -> void:
	var surface := Vector3(point.x, effects.sea_level(), point.z)
	effects.spawn(NearMissEffect.new(surface, blast_size))
	var offset := surface - enemies.global_position
	var distance := Vector2(offset.x, offset.z).length()
	var closeness := 1.0 - clampf(distance / felt_radius, 0.0, 1.0)
	if closeness <= 0.0:
		return
	turret.add_impulse(rock_impulse * closeness)
	lens.splash(closeness)
	if distance < shrapnel_radius:
		integrity.take_hit(shrapnel_damage * (1.0 - distance / shrapnel_radius), surface)
	elif randf() < douse_chance:
		integrity.repair(douse_amount)
