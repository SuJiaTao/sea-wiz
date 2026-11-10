extends SubViewportContainer
class_name ThermalView

const BASE_GAIN := 1.35
const SHAKE_GAIN := 0.05
const SHAKE_OFFSET := 0.0035
const BURST_GAIN_DROP := 0.45
const BURST_FLASH := 0.6
const FLASH_RECOVERY := 6.0
const GAIN_RECOVERY := 1.2
const MAX_RENDER_PIXELS := 1920.0 * 1080.0
const TARGET_FPS := 55.0
const FPS_HEADROOM := 4.0
const MIN_DYNAMIC_SCALE := 0.5
const SCALE_STEP := 0.1
const FPS_WINDOW := 1.0
const CALM_WINDOWS_TO_RAISE := 4

@export var turret: Turret
@export var afterglow: AfterglowBuffer
## 1.0 renders the world at the screen's real pixel count. Lower it on slow machines.
@export_range(0.5, 1.0) var render_scale: float = 1.0

var polarity: float = 0.0
var focus_error: float = 0.0

var _flash: float = 0.0
var _gain_dip: float = 0.0
var _sharp_blur: float = 0.0
var _dynamic_scale: float = 1.0
var _fps_clock: float = 0.0
var _calm_windows: int = 0

@onready var _thermal: ShaderMaterial = material as ShaderMaterial


func _ready() -> void:
	stretch = false
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	var image: Texture2D = $SubViewport.get_texture()
	_thermal.set_shader_parameter("sensor_image", image)
	_thermal.set_shader_parameter("trail_image", afterglow.get_texture() if afterglow != null else image)
	_sharp_blur = _thermal.get_shader_parameter("optical_blur")
	get_viewport().size_changed.connect(_update_sensor_size)
	_update_sensor_size()


func heat_burst(strength: float = 1.0) -> void:
	_flash = maxf(_flash, strength * BURST_FLASH)
	_gain_dip = maxf(_gain_dip, strength)


func _process(delta: float) -> void:
	_adapt_resolution(delta)
	var shake := 0.0
	if is_instance_valid(turret):
		shake = turret.shake_total()
	_flash = maxf(_flash - FLASH_RECOVERY * delta, 0.0)
	_gain_dip = maxf(_gain_dip - GAIN_RECOVERY * delta, 0.0)
	_thermal.set_shader_parameter("shake_x", randf_range(-shake, shake) * SHAKE_OFFSET)
	_thermal.set_shader_parameter("shake_y", randf_range(-shake, shake) * SHAKE_OFFSET)
	_thermal.set_shader_parameter("polarity", polarity)
	_thermal.set_shader_parameter("flash", _flash)
	_thermal.set_shader_parameter("optical_blur", clampf(_sharp_blur + focus_error, 0.0, 1.0))
	_thermal.set_shader_parameter(
		"gain", (BASE_GAIN + shake * SHAKE_GAIN) * (1.0 - BURST_GAIN_DROP * _gain_dip)
	)


func _update_sensor_size() -> void:
	var sensor_size := get_viewport().get_visible_rect().size
	var budget := sqrt(MAX_RENDER_PIXELS / maxf(sensor_size.x * sensor_size.y, 1.0))
	var pixels := minf(get_viewport().get_final_transform().get_scale().x, budget) * render_scale * _dynamic_scale
	var render_size := (sensor_size * pixels).round()
	$SubViewport.size = Vector2i(render_size)
	size = render_size
	scale = Vector2.ONE / pixels
	_thermal.set_shader_parameter("sensor_size", sensor_size.max(Vector2(64, 36)))
	if afterglow != null:
		afterglow.size = Vector2i(sensor_size)


# Drops the world's render resolution while the frame rate is low, and
# raises it back once there is headroom, so big windows stay smooth.
func _adapt_resolution(delta: float) -> void:
	_fps_clock += delta
	if _fps_clock < FPS_WINDOW:
		return
	_fps_clock = 0.0
	var fps := Engine.get_frames_per_second()
	var wanted := _dynamic_scale
	_calm_windows = _calm_windows + 1 if fps > TARGET_FPS + FPS_HEADROOM else 0
	if fps < TARGET_FPS:
		wanted = maxf(_dynamic_scale - SCALE_STEP, MIN_DYNAMIC_SCALE)
	elif _calm_windows >= CALM_WINDOWS_TO_RAISE:
		_calm_windows = 0
		wanted = minf(_dynamic_scale + SCALE_STEP * 0.5, 1.0)
	if not is_equal_approx(wanted, _dynamic_scale):
		_dynamic_scale = wanted
		_update_sensor_size()
