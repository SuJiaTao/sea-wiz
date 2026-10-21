extends HUDPanel
class_name WeaponFeedback

const LOCK_TONE: AudioStream = preload("res://audio/lock_tone.wav")
const LOCK_ACQUIRED: AudioStream = preload("res://audio/lock_acquired.wav")

@export var launcher: MissileLauncher
@export var turret: Turret
@export var smoke: MissileSmokeRenderer
@export var fx: FXManager

@onready var _seeker_audio: AudioStreamPlayer = $SeekerAudio

var _beep_remaining: float = 0.0
var _message_remaining: float = 0.0


func _ready() -> void:
	launcher.launched.connect(_on_launched)
	launcher.detonated.connect(_on_detonated)


func _on_launched(origin: Vector3, _target: AbstractEnemy) -> void:
	_message_remaining = 1.1
	_seeker_audio.stream = LOCK_ACQUIRED
	_seeker_audio.pitch_scale = 1.0
	_seeker_audio.play()
	smoke.play_launch(origin)
	turret.add_impulse(4.5)


func _on_detonated(position: Vector3, radius: float) -> void:
	fx.explosion(position, radius * 0.55)
	turret.add_impulse(0.6)


func _update_hud(delta: float) -> void:
	_message_remaining = maxf(_message_remaining - delta, 0.0)
	if get_tree().paused:
		_seeker_audio.stop()
		return

	if (
		not launcher.trigger_held
		or not is_instance_valid(launcher.lock_target)
		or launcher.lock_progress <= 0.0
		or not launcher.lock_denied_reason.is_empty()
	):
		_beep_remaining = 0.0
		if _seeker_audio.stream == LOCK_TONE:
			_seeker_audio.stop()
		return

	_beep_remaining -= delta
	if _beep_remaining <= 0.0:
		_beep_remaining = lerpf(0.46, 0.125, launcher.lock_progress)
		_seeker_audio.stream = LOCK_TONE
		_seeker_audio.pitch_scale = lerpf(0.85, 1.35, launcher.lock_progress)
		_seeker_audio.play()


func _draw() -> void:
	var origin := Vector2(28, size.y - 205)
	_text(origin - Vector2(0, 20), "Q / SIDE 1  HOLD TO LOCK", 11, FAINT)
	_text(origin, "CELLS", 12, DIM)
	for i in range(MissileLauncher.CAPACITY):
		var rect := Rect2(
			origin + Vector2(62 + i * 16, -11),
			Vector2(11, 12)
		)
		draw_rect(
			rect,
			MAIN if i < launcher.missiles else FAINT,
			i < launcher.missiles
		)

	if get_tree().paused:
		return

	if _message_remaining > 0.0:
		_center(
			size.y * 0.33, "MISSILE AWAY", 17,
			Color(1, 1, 1, clampf(_message_remaining / 0.4, 0, 1))
		)

	if not launcher.trigger_held:
		return

	var camera := turret.camera
	var center := size * 0.5
	if camera.fov <= MissileLauncher.LOCK_ZOOM_FOV:
		var distance := camera.near + 1.0
		var bore := camera.global_position - camera.global_basis.z * distance
		var edge := bore + camera.global_basis.x * (
			tan(deg_to_rad(MissileLauncher.LOCK_CONE_DEG)) * distance
		)
		var radius := _project_world(camera, bore).distance_to(
			_project_world(camera, edge)
		)
		draw_arc(center, maxf(radius, 10.0), 0, TAU, 40, FAINT)

	if not launcher.lock_denied_reason.is_empty():
		_center(center.y + 58, launcher.lock_denied_reason, 14)
		return

	var target := launcher.lock_target
	if not is_instance_valid(target):
		return
	if camera.is_position_behind(target.global_position):
		return

	var point := _project_world(camera, target.global_position)
	var progress := launcher.lock_progress
	var half := lerpf(64.0, 20.0, progress)
	var color := Color(1, 1, 1, 0.55 + 0.45 * progress)
	_draw_brackets(point, half, color, 2.0)
	if progress > 0.0:
		draw_arc(
			point, half + 10,
			-PI * 0.5, -PI * 0.5 + TAU * progress,
			40, color, 2.0
		)
	_text(
		point + Vector2(-40, half + 30),
		"SEEKER %d%%" % int(progress * 100.0), 12, color
	)
