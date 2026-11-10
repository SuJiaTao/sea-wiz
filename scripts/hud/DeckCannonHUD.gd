extends HUDPanel
class_name DeckCannonHUD

const LABEL_LIFT := Vector2(0, 20)
const BAR_OFFSET := Vector2(62, -10)
const BAR_SIZE := Vector2(128, 12)
const STATUS_OFFSET := Vector2(198, 0)
const HINT_FONT: int = 11
const LABEL_FONT: int = 12
const ORIGIN_OFFSET := Vector2(28, -330)
const MARKER_SIZE: float = 7.0
const MARKER_WIDTH: float = 1.5

@export var cannon: DeckCannon
@export var turret: Turret


func _draw() -> void:
	if get_tree().paused:
		return
	var origin := Vector2(0, size.y) + ORIGIN_OFFSET
	var loaded := cannon.reload_left <= 0.0
	var status := "READY" if loaded else "LOADING"
	var fill := 1.0 - cannon.reload_left / DeckCannon.RELOAD_TIME
	_text(origin - LABEL_LIFT, "SPACE  DECK GUN", HINT_FONT, FAINT)
	_text(origin, "GUN", LABEL_FONT, DIM)
	_bar(origin + BAR_OFFSET, BAR_SIZE, fill, MAIN if loaded else DIM)
	_text(origin + STATUS_OFFSET, status, LABEL_FONT, MAIN if loaded else DIM)
	_draw_fall_of_shot()


func _draw_fall_of_shot() -> void:
	var camera := turret.camera
	var muzzle := cannon.muzzle.global_position
	var reach := muzzle.distance_to(cannon.aim_point)
	var point := muzzle - cannon.muzzle.global_basis.z * reach
	if camera.is_position_behind(point):
		return
	var screen := _project_world(camera, point)
	var color := MAIN if cannon.on_target else FAINT
	var corners := PackedVector2Array([
		screen + Vector2(0, -MARKER_SIZE),
		screen + Vector2(MARKER_SIZE, 0),
		screen + Vector2(0, MARKER_SIZE),
		screen + Vector2(-MARKER_SIZE, 0),
		screen + Vector2(0, -MARKER_SIZE),
	])
	draw_polyline(corners, color, MARKER_WIDTH)
