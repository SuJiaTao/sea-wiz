extends CanvasLayer
class_name TitleScreen

# The title card: the CIWS with its gun pointing left and the deck below, all
# black against the glow just after sunset, riding the swell. Any button lets
# the dusk run on: the glow sinks and the sky darkens to night, and the
# screen goes dark before the game wakes up in night vision.

signal start_requested()
signal dusk_finished()

## How far into dusk the title sits before any button is pressed.
const DUSK_START: float = 0.12
## Eases the dusk in, so the glow lingers before the dark comes on.
const DUSK_CURVE: float = 1.6
const GLOW_BEARING: float = 93.0
const DUSK_TIME: float = 6.0
const TEXT_FADE_TIME: float = 0.8
const BLACKOUT_TIME: float = 1.3
## The ship rides a little high here so swells never wash over the foredeck.
const RIDE_HEIGHT: float = 1.5
const HEAVE: float = 0.22
const HEAVE_RATE: float = 0.55
const PITCH: float = 0.005
const PITCH_RATE: float = 0.41
const ROLL: float = 0.012
const ROLL_RATE: float = 0.33
const PROMPT_PULSE: float = 3.0
const CAMERA_POSITION := Vector3(-15.0, 13.2, -6.0)
const CAMERA_TARGET := Vector3(0.5, 12.3, -2.1)

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
	_set_dusk(DUSK_START)


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
		_set_dusk(lerpf(DUSK_START, 1.0, pow(_dusk, DUSK_CURVE)))
		_text.modulate.a = clampf(1.0 - _dusk * DUSK_TIME / TEXT_FADE_TIME, 0.0, 1.0)
		if _dusk >= 1.0:
			_blackout = 0.0
	if _blackout >= 0.0 and _blackout < 1.0:
		_blackout = minf(_blackout + delta / BLACKOUT_TIME, 1.0)
		_fade.color.a = _blackout
		if _blackout >= 1.0:
			dusk_finished.emit()


func _ride_swell() -> void:
	_vessel.position.y = RIDE_HEIGHT + sin(_clock * HEAVE_RATE) * HEAVE
	_vessel.rotation.x = sin(_clock * PITCH_RATE) * PITCH
	_vessel.rotation.z = sin(_clock * ROLL_RATE + 1.0) * ROLL


func _set_dusk(dusk: float) -> void:
	for material: ShaderMaterial in [sky, sea]:
		material.set_shader_parameter("dusk", dusk)
		material.set_shader_parameter("glow_bearing_deg", GLOW_BEARING)
