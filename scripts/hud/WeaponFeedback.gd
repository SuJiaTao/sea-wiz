extends HUDPanel
class_name WeaponFeedback

const LOCK_TONE: AudioStream = preload("res://audio/lock_tone.wav")
const LOCK_ACQUIRED: AudioStream = preload("res://audio/lock_acquired.wav")

@export var launcher: MissileLauncher
@export var salvos: SalvoManager
@export var turret: Turret
@export var smoke: MissileSmokeRenderer
@export var fx: FXManager

@onready var _seeker_audio: AudioStreamPlayer = $SeekerAudio

var _beep_remaining: float = 0.0
var _message_remaining: float = 0.0
var _message: String = ""
var _phase: float = 0.0


func _ready() -> void:
	launcher.launched.connect(_on_launched)
	launcher.detonated.connect(_on_detonated)
	salvos.started.connect(_on_salvo_started)
	salvos.rejected.connect(_on_salvo_rejected)


func _on_launched(
	origin: Vector3,
	_target: AbstractEnemy,
	mode: MissileLauncher.LaunchMode
) -> void:
	if mode == MissileLauncher.LaunchMode.SINGLE and not salvos.is_active():
		_show_message("MISSILE AWAY", 1.1)
	_seeker_audio.stream = LOCK_ACQUIRED
	_seeker_audio.pitch_scale = 1.0
	_seeker_audio.play()
	smoke.play_launch(origin)
	turret.apply_camera_shake_impulse(4.5)


func _on_detonated(position: Vector3, radius: float) -> void:
	fx.explosion(position, radius * 0.55)
	turret.apply_camera_shake_impulse(0.6)


func _update_hud(delta: float) -> void:
	_phase += delta
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
	_draw_salvo_status(origin)
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

	_draw_salvo_targets()

	if _message_remaining > 0.0:
		_center(
			size.y * 0.33, _message, 17,
			Color(1, 1, 1, clampf(_message_remaining / 0.4, 0, 1))
		)

	if not launcher.trigger_held:
		return

	var camera := turret.camera
	var center := size * 0.5
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


func _show_message(message: String, duration: float) -> void:
	_message = message
	_message_remaining = duration


func _on_salvo_started(target_count: int) -> void:
	_show_message("SALVO AWAY / %d TRACKS" % target_count, 2.0)


func _on_salvo_rejected(reason: SalvoManager.RejectReason) -> void:
	match reason:
		SalvoManager.RejectReason.DISABLED:
			_show_message("WEAPONS DISABLED", 1.6)
		SalvoManager.RejectReason.ACTIVE:
			_show_message("SALVO IN PROGRESS", 1.6)
		SalvoManager.RejectReason.CHARGING:
			_show_message(
				"SALVO CHARGING %d%%" % int(salvos.charge * 100.0),
				1.6
			)
		SalvoManager.RejectReason.NO_TARGETS:
			_show_message("NO CONTACTS IN FIELD", 1.6)
		SalvoManager.RejectReason.LAUNCH_UNAVAILABLE:
			_show_message("LAUNCH UNAVAILABLE", 1.6)


func _draw_salvo_status(origin: Vector2) -> void:
	var color := MAIN
	var status := "%d%%" % int(salvos.charge * 100.0)
	if salvos.is_active():
		status = "FIRING"
	elif salvos.is_ready():
		status = "READY"
		color = Color(1, 1, 1, 0.55 + 0.45 * sin(_phase * 7.0))

	_text(origin + Vector2(0, -72), "E / SIDE 2  SALVO", 11, FAINT)
	_text(origin + Vector2(0, -48), "SALVO", 12, DIM)
	_bar(
		origin + Vector2(62, -58),
		Vector2(128, 12),
		salvos.charge,
		color
	)
	_text(origin + Vector2(198, -48), status, 12, color)

	if salvos.combo > 1:
		_text(
			origin + Vector2(0, -92),
			"COMBO x%d" % salvos.combo,
			14,
			Color(
				1, 1, 1,
				0.6 + 0.4 * clampf(
					salvos.combo_remaining / SalvoManager.COMBO_WINDOW,
					0.0, 1.0
				)
			)
		)


func _draw_salvo_targets() -> void:
	var camera := turret.camera
	var color := Color(1, 1, 1, 0.6 + 0.4 * sin(_phase * 14.0))
	for target in salvos.pending_targets():
		if not camera.is_position_in_frustum(target.global_position):
			continue
		var point := _project_world(camera, target.global_position)
		if not Rect2(Vector2.ZERO, size).has_point(point):
			continue
		_draw_brackets(point, 22.0, color, 2.0)
		draw_line(
			point + Vector2(-8, 0),
			point + Vector2(8, 0), color
		)
		draw_line(
			point + Vector2(0, -8),
			point + Vector2(0, 8), color
		)
