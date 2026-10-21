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


func _project_world(camera: Camera3D, world_position: Vector3) -> Vector2:
	var viewport_size := Vector2(camera.get_viewport().get_visible_rect().size)
	return camera.unproject_position(world_position) / viewport_size * size


func _draw_brackets(
	point: Vector2,
	half: float,
	color: Color,
	width: float
) -> void:
	var length := half * 0.35
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			var corner := point + Vector2(x, y) * half
			draw_line(corner, corner - Vector2(x * length, 0), color, width)
			draw_line(corner, corner - Vector2(0, y * length), color, width)
