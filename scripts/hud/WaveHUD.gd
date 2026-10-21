extends HUDPanel
class_name WaveHUD

@export var waves: WaveOrchestrator
@export var enemies: EnemyManager

var _banner: String = ""
var _banner_remaining: float = 0.0


func _ready() -> void:
	waves.level_prepared.connect(_on_level_prepared)
	waves.level_started.connect(_on_level_started)


func _on_level_prepared(number: int, _title: String) -> void:
	_banner = "CONTACTS INBOUND" if number == 1 else "WAVE CLEAR / REARMING"
	_banner_remaining = 0.0


func _on_level_started(number: int, title: String) -> void:
	_banner = "LEVEL %02d — %s" % [number, title]
	_banner_remaining = 2.5


func _update_hud(delta: float) -> void:
	_banner_remaining = maxf(_banner_remaining - delta, 0.0)


func _draw() -> void:
	_text(
		Vector2(28, 82),
		"LEVEL %02d  %s" % [waves.level_number, waves.level_title], 16
	)
	_text(
		Vector2(28, 106),
		"CONTACTS  %02d" % enemies.active_count(), 12, DIM
	)

	if get_tree().paused:
		return

	if waves.intermission_remaining > 0.0:
		_center(size.y * 0.24, _banner, 28)
		_center(
			size.y * 0.24 + 30,
			"LEVEL %02d  %s  IN %.1f" % [
				waves.level_number,
				waves.level_title,
				waves.intermission_remaining
			], 16, DIM
		)
	elif _banner_remaining > 0.0:
		_center(
			size.y * 0.24, _banner, 28,
			Color(1, 1, 1, clampf(_banner_remaining / 0.6, 0, 1))
		)
