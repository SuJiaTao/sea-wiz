extends Control
class_name GameplayHUD

@export var turret: Turret
@export var waves: WaveOrchestrator
@export var thermal: ThermalView

var message: String = ""

var _hull: float = 100.0
var _max_hull: float = 100.0


func set_health(current: float, maximum: float) -> void:
	_hull = current
	_max_hull = maximum
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var color := Color(0.93, 0.98, 0.93, 0.95)
	var center := size * 0.5
	draw_line(center + Vector2(-12, 0), center + Vector2(12, 0), color)
	draw_line(center + Vector2(0, -12), center + Vector2(0, 12), color)
	var ammo_text := "AMMO %04d / %04d" % [turret.ammo, Turret.MAGAZINE]
	if turret.reloading:
		ammo_text += "  RELOADING"
	draw_string(font, Vector2(24, size.y - 76), ammo_text, 0, -1, 18, color)
	var hull_text := "HULL %03d%%" % int(100.0 * _hull / maxf(_max_hull, 1.0))
	draw_string(font, Vector2(24, size.y - 48), hull_text, 0, -1, 18, color)
	var level_text := "LEVEL %02d  %s" % [waves.level_number, waves.level_title]
	draw_string(font, Vector2(24, 32), level_text, 0, -1, 18, color)
	if waves.intermission_remaining > 0.0:
		draw_string(
			font, Vector2(24, 58),
			"INBOUND IN %.1f" % waves.intermission_remaining, 0, -1, 16, color
		)
	var polarity_text := "BLACK HOT" if thermal.polarity > 0.5 else "WHITE HOT"
	draw_string(
		font, Vector2(24, size.y - 20),
		"%s  FOV %.0f" % [polarity_text, turret.camera.fov], 0, -1, 14, color
	)
	if not message.is_empty():
		draw_string(
			font, Vector2(0, center.y + 60), message,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, color
		)
