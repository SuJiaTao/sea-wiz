extends Node
class_name RenderResolution
## How many real screen pixels the world is drawn with per canvas unit:
## the display's own density, capped to a pixel budget, and lowered while
## the frame rate is struggling.

signal changed()

const MAX_RENDER_PIXELS := 1920.0 * 1080.0
const TARGET_FPS := 55.0
const FPS_HEADROOM := 4.0
const MIN_DYNAMIC_SCALE := 0.5
const SCALE_STEP := 0.1
const RAISE_STEP := 0.05
const FPS_WINDOW := 1.0
const CALM_WINDOWS_TO_RAISE := 4

## 1.0 draws the world at the screen's real pixel count. Lower it on slow machines.
@export_range(0.5, 1.0) var render_scale: float = 1.0

var _dynamic_scale: float = 1.0
var _fps_clock: float = 0.0
var _calm_windows: int = 0


func pixels_per_unit(canvas_size: Vector2) -> float:
	var budget := sqrt(MAX_RENDER_PIXELS / maxf(canvas_size.x * canvas_size.y, 1.0))
	var density := get_viewport().get_final_transform().get_scale().x
	return minf(density, budget) * render_scale * _dynamic_scale


func _process(delta: float) -> void:
	_fps_clock += delta
	if _fps_clock < FPS_WINDOW:
		return
	_fps_clock = 0.0
	var fps := Engine.get_frames_per_second()
	_calm_windows = _calm_windows + 1 if fps > TARGET_FPS + FPS_HEADROOM else 0
	var wanted := _dynamic_scale
	if fps < TARGET_FPS:
		wanted = maxf(_dynamic_scale - SCALE_STEP, MIN_DYNAMIC_SCALE)
	elif _calm_windows >= CALM_WINDOWS_TO_RAISE:
		_calm_windows = 0
		wanted = minf(_dynamic_scale + RAISE_STEP, 1.0)
	if not is_equal_approx(wanted, _dynamic_scale):
		_dynamic_scale = wanted
		changed.emit()
