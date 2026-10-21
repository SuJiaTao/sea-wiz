extends HUDPanel
class_name CombatFeedbackHUD

@export var enemies: EnemyManager

var _hit_remaining: float = 0.0
var _kill_remaining: float = 0.0
var _splash_remaining: float = 0.0
var _splash_text: String = ""


func _ready() -> void:
	enemies.enemy_created.connect(_on_enemy_created)
	enemies.enemy_killed.connect(_on_enemy_killed)
	for enemy in enemies.live_enemies():
		_on_enemy_created(enemy)


func _on_enemy_created(enemy: AbstractEnemy) -> void:
	if not enemy.damaged.is_connected(_on_enemy_damaged):
		enemy.damaged.connect(_on_enemy_damaged)


func _on_enemy_damaged(_amount: float, _point: Vector3) -> void:
	_hit_remaining = 0.08


func _on_enemy_killed(enemy: AbstractEnemy, _weapon_source: Script) -> void:
	_kill_remaining = 0.22
	_splash_remaining = 1.3
	_splash_text = "SPLASH " + enemy.display_name


func _update_hud(delta: float) -> void:
	_hit_remaining = maxf(_hit_remaining - delta, 0.0)
	_kill_remaining = maxf(_kill_remaining - delta, 0.0)
	_splash_remaining = maxf(_splash_remaining - delta, 0.0)


func _draw() -> void:
	var center := size * 0.5
	if _kill_remaining > 0.0:
		_draw_ticks(
			center, 14, 30, 2.5,
			Color(1, 1, 1, clampf(_kill_remaining / 0.1, 0, 1))
		)
	elif _hit_remaining > 0.0:
		_draw_ticks(center, 11, 19, 1.5, MAIN)

	if _splash_remaining > 0.0:
		_center(
			center.y + 76, _splash_text, 14,
			Color(1, 1, 1, clampf(_splash_remaining / 0.6, 0, 1))
		)


func _draw_ticks(
	center: Vector2,
	inner: float,
	outer: float,
	width: float,
	color: Color
) -> void:
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			var direction := Vector2(x, y).normalized()
			draw_line(
				center + direction * inner,
				center + direction * outer,
				color, width
			)
