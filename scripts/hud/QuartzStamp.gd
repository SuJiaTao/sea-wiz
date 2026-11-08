extends HUDPanel
class_name QuartzStamp

const SEGMENTS := {
	"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
	"5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg",
}
const STAMP_COLOR := Color(1.0, 0.55, 0.12, 0.95)
const UNLIT_COLOR := Color(1.0, 0.45, 0.1, 0.06)
const DIGIT_WIDTH := 0.56
const THICKNESS := 0.14
const SEGMENT_GAP := 0.055
const DIGIT_GAP := 0.26
const FIELD_GAP := 0.55
const APOSTROPHE_WIDTH := 0.22
const APOSTROPHE_GAP := 0.12
const SLANT := 0.1
const HEIGHT_SHARE := 0.028
const LEFT_MARGIN := 28.0
const BOTTOM_MARGIN_SHARE := 0.025


func _draw() -> void:
	var height := size.y * HEIGHT_SHARE
	var date := Time.get_date_dict_from_system()
	var fields: Array[String] = [
		"%02d" % (date.year % 100), "%2d" % date.month, "%2d" % date.day,
	]
	var origin := Vector2(LEFT_MARGIN, size.y - size.y * BOTTOM_MARGIN_SHARE - height)
	var x := 0.0
	_bar_segment(origin, height, Rect2(APOSTROPHE_WIDTH * 0.3, 0.0, THICKNESS * 0.9, 0.3), STAMP_COLOR)
	x += APOSTROPHE_WIDTH + APOSTROPHE_GAP
	for field_index in fields.size():
		var field := fields[field_index]
		for character_index in field.length():
			_digit(origin, height, x, field[character_index])
			x += DIGIT_WIDTH + (DIGIT_GAP if character_index == 0 else 0.0)
		x += FIELD_GAP


func _digit(origin: Vector2, height: float, x: float, character: String) -> void:
	var lit: String = SEGMENTS.get(character, "")
	for segment in "abcdefg":
		var colour := STAMP_COLOR if lit.contains(segment) else UNLIT_COLOR
		_bar_segment(origin, height, _segment_rect(segment, x), colour)


func _segment_rect(segment: String, x: float) -> Rect2:
	var inset := THICKNESS * 0.55 + SEGMENT_GAP
	match segment:
		"a":
			return Rect2(x + inset, 0.0, DIGIT_WIDTH - 2.0 * inset, THICKNESS)
		"g":
			return Rect2(x + inset, 0.5 - THICKNESS * 0.5, DIGIT_WIDTH - 2.0 * inset, THICKNESS)
		"d":
			return Rect2(x + inset, 1.0 - THICKNESS, DIGIT_WIDTH - 2.0 * inset, THICKNESS)
	var left := segment == "f" or segment == "e"
	var upper := segment == "f" or segment == "b"
	var column := x if left else x + DIGIT_WIDTH - THICKNESS
	var top := THICKNESS * 0.5 + SEGMENT_GAP if upper else 0.5 + SEGMENT_GAP
	var bottom := 0.5 - SEGMENT_GAP if upper else 1.0 - THICKNESS * 0.5 - SEGMENT_GAP
	return Rect2(column, top, THICKNESS, bottom - top)


func _bar_segment(origin: Vector2, height: float, unit_rect: Rect2, colour: Color) -> void:
	var corners := PackedVector2Array()
	var unit_corners: Array[Vector2] = [
		unit_rect.position,
		unit_rect.position + Vector2(unit_rect.size.x, 0.0),
		unit_rect.end,
		unit_rect.position + Vector2(0.0, unit_rect.size.y),
	]
	for corner in unit_corners:
		var lean := (1.0 - corner.y) * SLANT
		corners.append(origin + Vector2(corner.x + lean, corner.y) * height)
	draw_colored_polygon(corners, colour)
