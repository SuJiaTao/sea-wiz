extends HUDPanel
class_name DeckWeaponHUD

# One deck weapon's slot line: its key, a ready bar, and a marker where its
# next shot would land when it has one.

const LABEL_LIFT := Vector2(0, 20)
const BAR_OFFSET := Vector2(62, -10)
const BAR_SIZE := Vector2(128, 12)
const STATUS_OFFSET := Vector2(198, 0)
const HINT_FONT: int = 11
const LABEL_FONT: int = 12
const MARKER_SIZE: float = 7.0
const MARKER_WIDTH: float = 1.5

@export var weapon: AbstractDeckWeapon
@export var turret: Turret
@export var loadout: ShipLoadout
@export var title := "DECK GUN"
@export var short_name := "GUN"
@export var busy_status := "LOADING"


func _draw() -> void:
	if get_tree().paused:
		return
	var origin := SlotLayout.origin(size, loadout.row_for(weapon.fitting))
	var fill := weapon.readiness()
	var loaded := fill >= 1.0
	var status := "READY" if loaded else busy_status
	_text(origin - LABEL_LIFT, "%s  %s" % [loadout.key_for(weapon.fitting), title], HINT_FONT, FAINT)
	_text(origin, short_name, LABEL_FONT, DIM)
	_bar(origin + BAR_OFFSET, BAR_SIZE, fill, MAIN if loaded else DIM)
	_text(origin + STATUS_OFFSET, status, LABEL_FONT, MAIN if loaded else DIM)
	_draw_fall_of_shot()


func _draw_fall_of_shot() -> void:
	var point := weapon.fall_of_shot()
	var camera := turret.camera
	if point == Vector3.INF or camera.is_position_behind(point):
		return
	var screen := _project_world(camera, point)
	var color := MAIN if weapon.on_target else FAINT
	var corners := PackedVector2Array([
		screen + Vector2(0, -MARKER_SIZE),
		screen + Vector2(MARKER_SIZE, 0),
		screen + Vector2(0, MARKER_SIZE),
		screen + Vector2(-MARKER_SIZE, 0),
		screen + Vector2(0, -MARKER_SIZE),
	])
	draw_polyline(corners, color, MARKER_WIDTH)
