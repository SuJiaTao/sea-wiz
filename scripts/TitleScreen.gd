extends CanvasLayer
class_name TitleScreen

# The title card: the CIWS with its gun pointing left and the deck below, all
# black against a red sunset, riding the swell. Any button sets the sun: it
# sinks, the sky drains to night, and the screen goes dark before the game
# wakes up in night vision.

signal start_requested()
signal dusk_finished()

const SUN_HIGH: float = 1.6
const SUN_GONE: float = -1.6
## Share of the dusk spent with the sun sinking into the sea before the light drains.
const SINK_SHARE: float = 0.6
const SUN_BEARING: float = 93.0
const DUSK_TIME: float = 5.5
const TEXT_FADE_TIME: float = 0.8
const BLACKOUT_TIME: float = 1.3
const HEAVE: float = 0.7
const HEAVE_RATE: float = 0.55
const PITCH: float = 0.018
const PITCH_RATE: float = 0.41
const ROLL: float = 0.03
const ROLL_RATE: float = 0.33
const PROMPT_PULSE: float = 3.0
const CAMERA_POSITION := Vector3(-16.0, 12.4, -6.0)
const CAMERA_TARGET := Vector3(-2.1, 14.8, 3.4)

@export var sky: ShaderMaterial
@export var sea: ShaderMaterial
@export var silhouette: Material

var _clock: float = 0.0
var _dusk: float = -1.0
var _blackout: float = -1.0

@onready var _vessel: Node3D = $Sunset/View/Vessel
@onready var _camera: Camera3D = $Sunset/View/Camera
@onready var _text: Control = $Text
@onready var _prompt: Label = $Text/Prompt
@onready var _fade: ColorRect = $Fade


func _ready() -> void:
	for part in _vessel.find_children("*", "GeometryInstance3D", true, false):
		(part as GeometryInstance3D).material_override = silhouette
	_camera.look_at_from_position(CAMERA_POSITION, CAMERA_TARGET, Vector3.UP)
	_set_sun(SUN_HIGH, 1.0)


func handle_input(event: InputEvent) -> bool:
	if not visible or _dusk >= 0.0:
		return false
	var pressed := (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed()
	if pressed and not event.is_echo():
		start_requested.emit()
		return true
	return false


func play_dusk() -> void:
	if _dusk < 0.0:
		_dusk = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	_ride_swell()
	_prompt.modulate.a = 0.5 + 0.45 * sin(_clock * PROMPT_PULSE)
	if _dusk >= 0.0 and _dusk < 1.0:
		_dusk = minf(_dusk + delta / DUSK_TIME, 1.0)
		var sinking := smoothstep(0.0, SINK_SHARE, _dusk)
		var draining := smoothstep(SINK_SHARE * 0.8, 1.0, _dusk)
		_set_sun(lerpf(SUN_HIGH, SUN_GONE, sinking), 1.0 - draining)
		_text.modulate.a = clampf(1.0 - _dusk * DUSK_TIME / TEXT_FADE_TIME, 0.0, 1.0)
		if _dusk >= 1.0:
			_blackout = 0.0
	if _blackout >= 0.0 and _blackout < 1.0:
		_blackout = minf(_blackout + delta / BLACKOUT_TIME, 1.0)
		_fade.color.a = _blackout
		if _blackout >= 1.0:
			dusk_finished.emit()


func _ride_swell() -> void:
	_vessel.position.y = sin(_clock * HEAVE_RATE) * HEAVE
	_vessel.rotation.x = sin(_clock * PITCH_RATE) * PITCH
	_vessel.rotation.z = sin(_clock * ROLL_RATE + 1.0) * ROLL


func _set_sun(elevation: float, daylight: float) -> void:
	for material: ShaderMaterial in [sky, sea]:
		material.set_shader_parameter("sun_elevation_deg", elevation)
		material.set_shader_parameter("sun_bearing_deg", SUN_BEARING)
		material.set_shader_parameter("daylight", daylight)
