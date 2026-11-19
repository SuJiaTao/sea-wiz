extends HUDPanel
class_name DeckWeaponHUD

# One deck weapon's slot line: its key, a ready bar, and a marker where its
# next shot would land when it has one. A weapon that fires on its own has no
# key, and lists on the right as AUTO.

const LABEL_LIFT := Vector2(0, 20)
const BAR_OFFSET := Vector2(62, -10)
const BAR_SIZE := Vector2(128, 12)
const STATUS_OFFSET := Vector2(198, 0)
const HINT_FONT: int = 11
const LABEL_FONT: int = 12
const MARKER_SIZE: float = 7.0
const MARKER_WIDTH: float = 1.5
const AUTO_KEY := "AUTO"
const AUTO_RIGHT_MARGIN: float = 300.0
const AUTO_TOP: float = 240.0
const AUTO_ROW_STEP: float = 44.0

@export var weapon: AbstractDeckWeapon
@export var turret: Turret
@export var loadout: ShipLoadout
@export var title := "DECK GUN"
@export var short_name := "GUN"
@export var busy_status := "LOADING"
## Where this weapon lists when it fires on its own.
@export var auto_row: int = 0


func _draw() -> void:
	if get_tree().paused:
		return
	var row := loadout.row_for(weapon.fitting)
	var key := loadout.key_for(weapon.fitting)
	var origin := SlotLayout.origin(size, row)
	if row < 0:
		key = AUTO_KEY
		origin = Vector2(size.x - AUTO_RIGHT_MARGIN, AUTO_TOP + AUTO_ROW_STEP * auto_row)
	var fill := weapon.readiness()
	var loaded := fill >= 1.0
	var status := "READY" if loaded else busy_status
	_text(origin - LABEL_LIFT, "%s  %s" % [key, title], HINT_FONT, FAINT)
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
