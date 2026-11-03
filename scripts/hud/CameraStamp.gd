extends HUDPanel
class_name CameraStamp

const BOTTOM_MARGIN := 18.0
const STAMP_SIZE := 11
const REC_BLINK_PERIOD := 1.0
const REC_DOT_RADIUS := 3.5
const REC_DOT_OFFSET := Vector2(-10.0, -4.0)
const TIMECODE_FPS := 30
const NARROW_FOV_BELOW := 40.0
const CAMERA_NAME := "CIWS 1  IR"

@export var turret: Turret

var _recording_time: float = 0.0


func _update_hud(delta: float) -> void:
	_recording_time += delta


func _draw() -> void:
	var stamp := "REC   %s   TC %s   %s   %s" % [
		Time.get_datetime_string_from_system(true, true) + "Z",
		_timecode(),
		CAMERA_NAME,
		_field_of_view_label(),
	]
	var width := ThemeDB.fallback_font.get_string_size(
		stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, STAMP_SIZE
	).x
	var origin := Vector2((size.x - width) * 0.5, size.y - BOTTOM_MARGIN)
	if fmod(_recording_time, REC_BLINK_PERIOD) < REC_BLINK_PERIOD * 0.5:
		draw_circle(origin + REC_DOT_OFFSET, REC_DOT_RADIUS, MAIN)
	_text(origin, stamp, STAMP_SIZE, DIM)


func _timecode() -> String:
	var frames := floori(_recording_time * TIMECODE_FPS)
	var seconds := floori(_recording_time)
	return "%02d:%02d:%02d:%02d" % [
		floori(seconds / 3600.0), floori(seconds / 60.0) % 60, seconds % 60, frames % TIMECODE_FPS
	]


func _field_of_view_label() -> String:
	if turret == null or turret.camera == null:
		return ""
	return "NFOV" if turret.camera.fov < NARROW_FOV_BELOW else "WFOV"
