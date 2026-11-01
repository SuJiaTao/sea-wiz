extends Node
class_name ScoreKeeper

signal scored(points: int, label: String, multiplier: int)

@export var enemies: EnemyManager
@export var combo_window: float = 4.0
@export var max_multiplier: int = 5

var score: int = 0
var best: int = 0
var finished: bool = false
var new_best: bool = false
var combo: ComboChain


func _ready() -> void:
	combo = ComboChain.new(combo_window, max_multiplier)
	best = HighScoreStore.load_best()
	enemies.enemy_killed.connect(_on_enemy_killed)


func _process(delta: float) -> void:
	combo.tick(delta)


func award(base_points: int, label: String) -> void:
	if finished or base_points <= 0:
		return
	var points := base_points * combo.multiplier
	score += points
	scored.emit(points, label, combo.multiplier)


func record_final() -> void:
	if finished:
		return
	finished = true
	if score > best:
		best = score
		new_best = true
		HighScoreStore.save_best(best)


func _on_enemy_killed(enemy: AbstractEnemy, _weapon_source: DamageSource) -> void:
	combo.extend()
	award(enemy.score_points(), enemy.score_label())
