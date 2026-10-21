extends Control
class_name HUDPanel

const MAIN := Color(0.93, 0.98, 0.93, 0.95)
const DIM := Color(0.62, 0.70, 0.62, 0.70)
const FAINT := Color(0.45, 0.52, 0.45, 0.45)


func _process(delta: float) -> void:
	_update_hud(0.0 if get_tree().paused else delta)
	queue_redraw()


func _update_hud(_delta: float) -> void:
	pass


func _text(
	position: Vector2,
	value: String,
	font_size: int = 13,
	color: Color = MAIN
) -> void:
	draw_string(
		ThemeDB.fallback_font, position, value,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color
	)


func _center(
	y: float,
	value: String,
	font_size: int = 18,
	color: Color = MAIN
) -> void:
	draw_string(
		ThemeDB.fallback_font, Vector2(0, y), value,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, color
	)


func _bar(
	position: Vector2,
	dimensions: Vector2,
	fraction: float,
	color: Color = MAIN
) -> void:
	draw_rect(Rect2(position, dimensions), FAINT, false)
	var fill := Vector2(
		(dimensions.x - 4.0) * clampf(fraction, 0.0, 1.0),
		dimensions.y - 4.0
	)
	draw_rect(Rect2(position + Vector2(2, 2), fill), color)
