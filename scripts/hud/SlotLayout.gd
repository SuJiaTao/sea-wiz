extends RefCounted
class_name SlotLayout

const LEFT_MARGIN: float = 28.0
const TOP_ROW_FROM_BOTTOM: float = 420.0
const ROW_STEP: float = 48.0


static func origin(panel_size: Vector2, row: int) -> Vector2:
	return Vector2(LEFT_MARGIN, panel_size.y - TOP_ROW_FROM_BOTTOM + ROW_STEP * row)
