extends Node3D
class_name Turret

signal fired(origin: Vector3, direction: Vector3)
signal reload_started()
signal reload_finished()

const GUN_SCENE := preload("res://scenes/turret/Gun.tscn")
const LAUNCHER_SCENE := preload("res://scenes/turret/Launcher.tscn")
const RADOME_SCENE := preload("res://scenes/turret/Radome.tscn")

const MUZZLE_VELOCITY := 900.0
const ROUNDS_PER_MIN := 4500.0
const MAGAZINE := 1550
const RELOAD_TIME := 2.4
const SPINUP_TIME := 0.32
const SPINDOWN_TIME := 0.8

const PITCH_MIN := deg_to_rad(-12.0)
const PITCH_MAX := deg_to_rad(80.0)

const SHAKE_PER_ROUND := 0.34
const SHAKE_CAP := 2.4
const SHAKE_DECAY := 7.0
const IMPULSE_DECAY := 12.0
const IMPULSE_CAP := 6.0
const SHAKE_TO_OFFSET := 0.015

const FOV_WIDE := 55.0
const FOV_NARROW := 17.0

const CAMERA_OFFSET := Vector3(0.0, 1.05, 0.95)
const LAUNCHER_OFFSET := Vector3(0.0, 3.30, 3.15)

@export_category("Camera Movement Properties")
@export var mouse_sensitivity: float = 0.0022
@export var damage_source: DamageSource
@export var slew_speed: float = 1.5
@export var dispersion_deg: float = 0.30
@export var wander_deg: float = 0.22
@export_category("Componenets")
@export var mount: Node3D
@export var gun: Node3D
@export var barrels: Node3D
@export var muzzle: Marker3D
@export var camera: Camera3D
@export var flash: MeshInstance3D
@export var launcher: Node3D
@export_category("Audio Players")
@export var _gun_audio: AudioStreamPlayer
@export var _spin_audio: AudioStreamPlayer

var ammo: int = MAGAZINE
var reloading: bool = false
var firing: bool = false
var spin: float = 0.0
var shake: float = 0.0
var impulse: float = 0.0
var zoom_level: float = 0.0
var hide_gun: bool = false

var _reload_timer: float = 0.0
var _fire_accum: float = 0.0
var _barrel_angle: float = 0.0
var _flash_timer: float = 0.0
var _wander := Vector2.ZERO
var _wander_target := Vector2.ZERO
var _wander_timer: float = 0.0
var _recoil: float = 0.0
var _enabled: bool = true


func set_enabled(value: bool) -> void:
	_enabled = value
	if not value:
		firing = false
		_gun_audio.stop()
		_spin_audio.stop()


func apply_mouse_motion(relative: Vector2) -> void:
	if not _enabled or camera == null:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var scale_by_fov: float = camera.fov / FOV_WIDE
	aim(
		-relative.x * mouse_sensitivity * scale_by_fov,
		-relative.y * mouse_sensitivity * scale_by_fov
	)


func nudge_zoom(amount: float) -> void:
	zoom_level = clampf(zoom_level + amount, 0.0, 1.0)


func aim(dyaw: float, dpitch: float) -> void:
	rotate_y(dyaw)
	mount.rotation.x = clampf(mount.rotation.x + dpitch, PITCH_MIN, PITCH_MAX)


func add_impulse(value: float) -> void:
	impulse = minf(impulse + value, IMPULSE_CAP)


func shake_total() -> float:
	return shake + impulse


func bearing_deg() -> float:
	return fposmod(-rad_to_deg(rotation.y), 360.0)


func elevation_deg() -> float:
	return rad_to_deg(mount.rotation.x)


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		flash.visible = randf() < 0.6
		flash.scale = Vector3.ONE * randf_range(0.5, 1.2)
		flash.rotation.z = randf() * TAU
	else:
		flash.visible = false

	_recoil = lerpf(_recoil, 0.0, clampf(delta * 9.0, 0.0, 1.0))
	shake = lerpf(shake, 0.0, clampf(delta * SHAKE_DECAY, 0.0, 1.0))
	impulse = lerpf(impulse, 0.0, clampf(delta * IMPULSE_DECAY, 0.0, 1.0))
	if camera != null:
		camera.position = CAMERA_OFFSET + Vector3(0.0, 0.0, _recoil * 0.22)
		var amount: float = shake_total()
		camera.h_offset = randf_range(-amount, amount) * SHAKE_TO_OFFSET
		camera.v_offset = randf_range(-amount, amount) * SHAKE_TO_OFFSET

	if barrels != null:
		_barrel_angle += spin * TAU * 12.0 * delta
		barrels.rotation.z = _barrel_angle

	if gun != null and camera != null:
		gun.visible = camera.fov > 32.0 and not hide_gun


func _physics_process(delta: float) -> void:
	if not _enabled:
		spin = move_toward(spin, 0.0, delta / SPINDOWN_TIME)
		_update_audio()
		return

	var horizontal := (
		Input.get_action_strength("ciws_slew_left")
		- Input.get_action_strength("ciws_slew_right")
	)
	var vertical := (
		Input.get_action_strength("ciws_slew_up")
		- Input.get_action_strength("ciws_slew_down")
	)
	if horizontal != 0.0 or vertical != 0.0:
		var scale_by_fov: float = camera.fov / FOV_WIDE
		aim(
			horizontal * slew_speed * scale_by_fov * delta,
			vertical * slew_speed * scale_by_fov * delta
		)

	var zoom := maxf(
		zoom_level,
		1.0 if Input.is_action_pressed("ciws_zoom") else 0.0
	)
	var desired_fov := lerpf(FOV_WIDE, FOV_NARROW, zoom)
	camera.fov = lerpf(camera.fov, desired_fov, clampf(delta * 8.0, 0.0, 1.0))

	if reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			reloading = false
			ammo = MAGAZINE
			reload_finished.emit()
	elif Input.is_action_just_pressed("ciws_reload") and ammo < MAGAZINE:
		_start_reload()
	elif ammo <= 0:
		_start_reload()

	firing = Input.is_action_pressed("ciws_fire") and ammo > 0 and not reloading
	if firing:
		spin = move_toward(spin, 1.0, delta / SPINUP_TIME)
	else:
		spin = move_toward(spin, 0.0, delta / SPINDOWN_TIME)

	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(0.15, 0.4)
		_wander_target = Vector2(
			randfn(0.0, 1.0), randfn(0.0, 1.0)
		) * deg_to_rad(wander_deg)
	_wander = _wander.lerp(_wander_target, clampf(delta * 6.0, 0.0, 1.0))

	if firing:
		var rate: float = (ROUNDS_PER_MIN / 60.0) * spin
		_fire_accum += rate * delta
		while _fire_accum >= 1.0 and ammo > 0:
			_fire_accum -= 1.0
			_emit_round()
		if ammo <= 0:
			_start_reload()
	else:
		_fire_accum = 0.0

	_update_audio()


func _start_reload() -> void:
	if reloading:
		return
	reloading = true
	_reload_timer = RELOAD_TIME
	reload_started.emit()


func _emit_round() -> void:
	ammo -= 1
	var origin := muzzle.global_position
	var forward := -muzzle.global_transform.basis.z
	var sigma := deg_to_rad(dispersion_deg)
	var yaw_offset := randfn(0.0, sigma) + _wander.x
	var pitch_offset := randfn(0.0, sigma) + _wander.y
	var right := forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	var up := right.cross(forward).normalized()
	var direction := (
		forward + right * tan(yaw_offset) + up * tan(pitch_offset)
	).normalized()

	fired.emit(origin, direction * MUZZLE_VELOCITY)
	_flash_timer = 0.035
	_recoil = minf(_recoil + 0.05, 0.35)
	shake = minf(shake + SHAKE_PER_ROUND, SHAKE_CAP)


func _update_audio() -> void:
	if _gun_audio.stream != null:
		if firing and spin > 0.25:
			if not _gun_audio.playing:
				_gun_audio.play()
			_gun_audio.pitch_scale = lerpf(0.72, 1.0, spin)
		elif _gun_audio.playing:
			_gun_audio.stop()
	if _spin_audio.stream != null:
		if spin > 0.02:
			if not _spin_audio.playing:
				_spin_audio.play()
			_spin_audio.pitch_scale = lerpf(0.55, 1.15, spin)
			_spin_audio.volume_db = lerpf(-30.0, -13.0, spin)
		elif _spin_audio.playing:
			_spin_audio.stop()
