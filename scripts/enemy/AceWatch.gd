extends Node
class_name AceWatch

# What the ace does to the world beyond his own jet: his jamming blinds our
# radar for a while, and when he punches out his seat fires clear of the jet
# in a flash and a streak of smoke.

const SEAT_SPARKS: int = 30
const SEAT_ENERGY: float = 2.0
const SEAT_PUFFS: int = 10
const SEAT_RISE: float = 30.0
const SEAT_PUFF_SIZE: float = 0.8
const SEAT_PUFF_LIFE: float = 2.5

@export var enemies: EnemyManager
@export var radar: SearchRadar
@export var effects: EffectManager
@export var fx: FXManager


func _ready() -> void:
	enemies.enemy_created.connect(_on_enemy_created)


func _on_enemy_created(enemy: AbstractEnemy) -> void:
	var ace := enemy as AceJetEnemy
	if ace == null:
		return
	ace.jamming.connect(radar.jam)
	ace.ejected.connect(_on_ejected)


func _on_ejected(at: Vector3, carried: Vector3) -> void:
	fx.spark_burst(at, SEAT_SPARKS, SEAT_ENERGY)
	for puff in SEAT_PUFFS:
		var rise := Vector3.UP * SEAT_RISE * float(puff) / SEAT_PUFFS
		effects.smoke.emit(at + rise * 0.1, carried * 0.3 + rise, SEAT_PUFF_SIZE, SEAT_PUFF_LIFE)
