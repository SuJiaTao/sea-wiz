extends HUDPanel
class_name GunneryHUD

# Corner brackets on the enemy ship the deck guns are firing at.

const BRACKET: float = 26.0
const ARM: float = 9.0
const WIDTH: float = 1.5
const LABEL := "GUNS"
const LABEL_OFFSET := Vector2(-BRACKET, -BRACKET - 6.0)

@export var gunnery: SurfaceGunnery
@export var turret: Turret


func _draw() -> void:
	if get_tree().paused or not gunnery.has_target():
		return
	var at := gunnery.target.global_position
	if turret.camera.is_position_behind(at):
		return
	var centre := _project_world(turret.camera, at)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var tip := centre + corner * BRACKET
		draw_line(tip, tip - Vector2(corner.x * ARM, 0), MAIN, WIDTH)
		draw_line(tip, tip - Vector2(0, corner.y * ARM), MAIN, WIDTH)
	_text(centre + LABEL_OFFSET, LABEL, 11, MAIN)
