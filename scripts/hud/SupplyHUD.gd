extends HUDPanel
class_name SupplyHUD

const INBOUND_MESSAGE := "RESUPPLY INBOUND  /  FRIENDLY  /  HOLD FIRE"
const RECOVERED_MESSAGE := "RESUPPLY RECOVERED"
const LOST_MESSAGE := "RESUPPLY LOST"
const INBOUND_TONE: AudioStream = preload("res://audio/supply/supply_inbound.wav")
const RECOVERED_TONE: AudioStream = preload("res://audio/supply/supply_recovered.wav")
const LOST_TONE: AudioStream = preload("res://audio/supply/supply_lost.wav")
const MESSAGE_TIME: float = 3.0
const MESSAGE_HEIGHT: float = 0.3
const MESSAGE_FONT: int = 16
const MARKER_HALF: float = 12.0
const MARKER_WIDTH: float = 1.5
const LABEL_OFFSET := Vector2(18, 4)
const LABEL_FONT: int = 11
const METRES_PER_KM: float = 1000.0
const MARKER_LIFT := Vector3(0.0, 4.0, 0.0)

@export var supplies: SupplyDrops
@export var turret: Turret

var _message: String = ""
var _message_left: float = 0.0
var _tone: AudioStreamPlayer


func _ready() -> void:
	_tone = AudioStreamPlayer.new()
	add_child(_tone)
	supplies.inbound.connect(_announce.bind(INBOUND_MESSAGE, INBOUND_TONE))
	supplies.recovered.connect(_announce.bind(RECOVERED_MESSAGE, RECOVERED_TONE))
	supplies.lost.connect(_announce.bind(LOST_MESSAGE, LOST_TONE))


func _update_hud(delta: float) -> void:
	_message_left = maxf(_message_left - delta, 0.0)


func _draw() -> void:
	if get_tree().paused or supplies.is_choosing():
		return
	if _message_left > 0.0:
		_center(size.y * MESSAGE_HEIGHT, _message, MESSAGE_FONT)
	_draw_crate_marker()


func _draw_crate_marker() -> void:
	var crate := supplies.crate
	if not is_instance_valid(crate) or not crate.alive:
		return
	var camera := turret.camera
	var centre := crate.global_position + MARKER_LIFT
	if camera.is_position_behind(centre):
		return
	var point := _project_world(camera, centre)
	var corners := PackedVector2Array([
		point + Vector2.UP * MARKER_HALF, point + Vector2.RIGHT * MARKER_HALF,
		point + Vector2.DOWN * MARKER_HALF, point + Vector2.LEFT * MARKER_HALF,
		point + Vector2.UP * MARKER_HALF,
	])
	draw_polyline(corners, MAIN, MARKER_WIDTH)
	var range_km := camera.global_position.distance_to(centre) / METRES_PER_KM
	_text(point + LABEL_OFFSET, "RESUPPLY  %.1f KM" % range_km, LABEL_FONT)


func _announce(message: String, tone: AudioStream) -> void:
	_message = message
	_message_left = MESSAGE_TIME
	_tone.stream = tone
	_tone.play()
