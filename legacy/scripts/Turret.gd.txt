extends Node3D
class_name Turret
## The mount. Builds its own node tree so the scene file stays trivial.
##
##   Turret (this, yaw)
##     Mount (pitch)
##       Gun      - barrel cluster, spins while firing
##       Muzzle   - Marker3D at the barrel tips
##       Camera3D - the sensor head, slaved to the gun

signal fired(origin: Vector3, direction: Vector3)
signal reload_started()
signal reload_finished()
signal missile_launched(origin: Vector3, direction: Vector3, target: Enemy)
signal salvo_started(count: int)

const MUZZLE_VELOCITY := 900.0      # m/s, 20mm
const ROUNDS_PER_MIN := 4500.0
const MAGAZINE := 1550
const RELOAD_TIME := 2.4
const SPINUP_TIME := 0.32
const SPINDOWN_TIME := 0.8

const PITCH_MIN := deg_to_rad(-12.0)
const PITCH_MAX := deg_to_rad(80.0)

# --- Screen shake -----------------------------------------------------------
# Two channels, because they do different jobs. `shake` is the sustained
# judder of the gun running: it saturates almost instantly while firing and
# unwinds when you stop. `impulse` is a hard, fast-decaying kick for one-off
# events - a missile leaving the cell, something getting through to the hull.
# Summing one channel for both would mean a launch either got lost under the
# gun rumble or left the picture shaking for a second afterwards.
const SHAKE_PER_ROUND := 0.34
const SHAKE_CAP := 2.4
const SHAKE_DECAY := 7.0
const IMPULSE_DECAY := 12.0
const IMPULSE_CAP := 6.0
## World-units of frustum offset per unit of shake.
const SHAKE_TO_OFFSET := 0.015

const FOV_WIDE := 55.0
const FOV_NARROW := 17.0

## Sensor head position relative to the gun's trunnion. Sitting above and
## behind the breech puts the barrel cluster in the bottom of the frame
## without the bore-sight parallax becoming noticeable at engagement ranges.
const CAMERA_OFFSET := Vector3(0.0, 1.05, 0.95)

# --- Missiles --------------------------------------------------------------
# The launcher rides the yaw platform behind and above the sensor, so a shot
# climbs out from behind you and crosses the frame on its way downrange.
const LAUNCHER_OFFSET := Vector3(0.0, 3.30, 3.15)
const MISSILE_CAPACITY := 8
const MISSILE_REGEN := 9.0            # seconds per rearmed cell
const LOCK_TIME := 2.45               # seconds of steady tracking to lock
const LOCK_CONE_DEG := 3.2            # how tight you have to hold the bore
const LOCK_MIN_RANGE := 130.0         # the seeker will not take a snap shot
const LOCK_MAX_RANGE := 2800.0
const LOCK_ZOOM_FOV := 38.0           # must be zoomed in at least this far
const REFIRE_DELAY := 0.55

# --- Salvo -----------------------------------------------------------------
# The special. Charge is earned with the gun, so it is a reward for shooting
# well rather than a second trigger.
const SALVO_MAX_TARGETS := 12
const SALVO_RIPPLE := 0.11            # seconds between cells
const SALVO_CHARGE_PER_KILL := 0.085
const COMBO_WINDOW := 4.0
const COMBO_MAX := 12

@export var mouse_sensitivity: float = 0.0022
@export var damage_source: DamageSource
@export var guided_weapons_enabled: bool = false
@export var slew_speed: float = 1.5
@export var dispersion_deg: float = 0.30    # 1-sigma cone half-angle
@export var wander_deg: float = 0.22        # slow barrel whip

var mount: Node3D
var gun: Node3D
var barrels: Node3D
var muzzle: Marker3D
var camera: Camera3D
var flash: MeshInstance3D

var ammo: int = MAGAZINE
var reloading: bool = false
var firing: bool = false
var spin: float = 0.0                        # 0..1 barrel spin-up
## Sustained judder while the gun runs.
var shake: float = 0.0
## Transient kick, decays fast. Use add_impulse().
var impulse: float = 0.0
var rounds_fired_total: int = 0
## Persistent wheel zoom, 0 = wide field, 1 = fully narrow.
var zoom_level: float = 0.0

# Fire control
var launcher: Node3D
var missiles: int = MISSILE_CAPACITY
var lock_target: Enemy = null
var lock_progress: float = 0.0
var lock_denied_reason: String = ""
var salvo_charge: float = 0.0
var salvo_targets: Array = []
var combo: int = 0
var combo_timer: float = 0.0
var missile_input: bool = false

var _missile_regen_t: float = 0.0
var _refire_t: float = 0.0
var _lock_beep_t: float = 0.0
var _salvo_queue: Array = []          # [{target, t}]
var _salvo_t: float = 0.0
var _lock_tone: AudioStream
var _lock_done: AudioStream
var _lock_audio: AudioStreamPlayer

var _reload_timer: float = 0.0
var _fire_accum: float = 0.0
var _barrel_angle: float = 0.0
var _flash_timer: float = 0.0
var _wander := Vector2.ZERO
var _wander_target := Vector2.ZERO
var _wander_timer: float = 0.0
var _recoil: float = 0.0
var _enabled: bool = true

## Set by the demo/attract gunner. Ignored during normal play.
var force_fire: bool = false
## Title screen hides the barrels so the menu text reads cleanly.
var hide_gun: bool = false
const SLEW_RATE := deg_to_rad(115.0)   # degrees/sec the mount can traverse

var _gun_audio: AudioStreamPlayer
var _spin_audio: AudioStreamPlayer


func _ready() -> void:
	mount = Node3D.new()
	mount.name = "Mount"
	mount.position = Vector3(0, 2.0, 0)
	add_child(mount)

	# Search/track radome. It yaws with the mount but does not elevate, and it
	# is deliberately parked BEHIND the sensor head so it never eats the frame.
	var radome := MeshFactory.build_radome()
	radome.name = "Radome"
	radome.position = Vector3(0, 1.6, 3.4)
	add_child(radome)

	launcher = MeshFactory.build_launcher()
	launcher.name = "Launcher"
	launcher.position = LAUNCHER_OFFSET
	add_child(launcher)

	gun = MeshFactory.build_gun()
	gun.name = "Gun"
	mount.add_child(gun)
	barrels = gun.get_node_or_null("BarrelCluster")

	muzzle = Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0, -2.2)
	mount.add_child(muzzle)

	# Muzzle flash: a flat, very hot quad that pops for one or two frames.
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 0.3)
	flash = MeshInstance3D.new()
	flash.mesh = q
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(3.2, 3.2, 2.8, 1.0)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.disable_receive_shadows = true
	flash.material_override = fm
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.position = Vector3(0, 0, -2.35)
	flash.visible = false
	mount.add_child(flash)

	camera = Camera3D.new()
	camera.name = "Sensor"
	camera.fov = FOV_WIDE
	camera.near = 0.1
	camera.far = 6000.0
	camera.position = CAMERA_OFFSET
	camera.current = true
	mount.add_child(camera)

	_gun_audio = AudioStreamPlayer.new()
	_gun_audio.bus = "Master"
	_gun_audio.volume_db = -4.0
	add_child(_gun_audio)

	_spin_audio = AudioStreamPlayer.new()
	_spin_audio.bus = "Master"
	_spin_audio.volume_db = -14.0
	add_child(_spin_audio)

	_lock_audio = AudioStreamPlayer.new()
	_lock_audio.bus = "Master"
	_lock_audio.volume_db = -9.0
	add_child(_lock_audio)

	_load_audio()


func _load_audio() -> void:
	var fire_stream := _load_looping("res://audio/ciws_fire.wav")
	if fire_stream != null:
		_gun_audio.stream = fire_stream
	var spin_stream := _load_looping("res://audio/ciws_spin.wav")
	if spin_stream != null:
		_spin_audio.stream = spin_stream
	if ResourceLoader.exists("res://audio/lock_tone.wav"):
		_lock_tone = load("res://audio/lock_tone.wav")
	if ResourceLoader.exists("res://audio/lock_acquired.wav"):
		_lock_done = load("res://audio/lock_acquired.wav")


func _load_looping(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var s := load(path)
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * float(w.mix_rate))
		return w
	return s


func set_enabled(v: bool) -> void:
	_enabled = v
	if not v:
		firing = false
		missile_input = false
		_clear_lock()
		_gun_audio.stop()
		_spin_audio.stop()


## Called by Game with raw mouse deltas.
##
## This is deliberately NOT an _unhandled_input handler: the turret lives
## inside a SubViewport, and a SubViewport whose container ignores the mouse
## never sees input pushed into the root viewport. Routing the motion in from
## the root node is the only reliable path.
func apply_mouse_motion(relative: Vector2) -> void:
	if not _enabled or camera == null:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	# Scale with the current field of view so zoomed-in tracking stays fine.
	var scale_by_fov: float = camera.fov / FOV_WIDE
	aim(-relative.x * mouse_sensitivity * scale_by_fov,
		-relative.y * mouse_sensitivity * scale_by_fov)


## Wheel zoom, in steps. 0 = wide, 1 = fully narrow.
func nudge_zoom(amount: float) -> void:
	zoom_level = clampf(zoom_level + amount, 0.0, 1.0)


func aim(dyaw: float, dpitch: float) -> void:
	rotate_y(dyaw)
	mount.rotation.x = clampf(mount.rotation.x + dpitch, PITCH_MIN, PITCH_MAX)


## Slew the mount toward a world point at a bounded rate. Used by the demo
## gunner; also handy if you ever want a radar-cued auto-track mode.
func slew_toward(world_point: Vector3, delta: float) -> void:
	var rel := world_point - mount.global_position
	if rel.length_squared() < 1.0:
		return
	var want_yaw := atan2(-rel.x, -rel.z)
	var flat := Vector2(rel.x, rel.z).length()
	var want_pitch := atan2(rel.y, flat)
	var step := SLEW_RATE * delta
	var dyaw := wrapf(want_yaw - rotation.y, -PI, PI)
	rotation.y += clampf(dyaw, -step, step)
	var dpitch := want_pitch - mount.rotation.x
	mount.rotation.x = clampf(mount.rotation.x + clampf(dpitch, -step, step),
			PITCH_MIN, PITCH_MAX)


## One-off kick. Decays much faster than the gun judder.
func add_impulse(v: float) -> void:
	impulse = minf(impulse + v, IMPULSE_CAP)


## What the camera and the sensor shader should actually shake by.
func shake_total() -> float:
	return shake + impulse


func bearing_deg() -> float:
	return fposmod(-rad_to_deg(rotation.y), 360.0)


func elevation_deg() -> float:
	return rad_to_deg(mount.rotation.x)


func _process(delta: float) -> void:
	# Flash and recoil decay run on the render frame so they look crisp.
	if _flash_timer > 0.0:
		_flash_timer -= delta
		# Flicker rather than a solid square: real muzzle flash strobes with
		# the rounds, and a constant block reads as a rendering fault.
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
		# h_offset/v_offset shift the frustum rather than rotating the mount,
		# so the bore stays true while the picture shakes - and unproject_position
		# follows, which keeps every HUD marker pinned to its contact.
		var s: float = shake_total()
		camera.h_offset = randf_range(-s, s) * SHAKE_TO_OFFSET
		camera.v_offset = randf_range(-s, s) * SHAKE_TO_OFFSET

	if barrels != null:
		_barrel_angle += spin * TAU * 12.0 * delta
		barrels.rotation.z = _barrel_angle

	# The narrow field is a separate optic that does not look past the barrels.
	# Without this, zooming magnifies the gun itself and swallows the frame.
	if gun != null and camera != null:
		gun.visible = camera.fov > 32.0 and not hide_gun


func _physics_process(delta: float) -> void:
	if not _enabled:
		spin = move_toward(spin, 0.0, delta / SPINDOWN_TIME)
		_update_audio()
		return

	# Keyboard slew as an alternative to the mouse.
	var kx := Input.get_action_strength("ciws_slew_left") - Input.get_action_strength("ciws_slew_right")
	var ky := Input.get_action_strength("ciws_slew_up") - Input.get_action_strength("ciws_slew_down")
	if kx != 0.0 or ky != 0.0:
		var f: float = camera.fov / FOV_WIDE
		aim(kx * slew_speed * f * delta, ky * slew_speed * f * delta)

	# Sensor zoom: the wheel sets a persistent level, right mouse snaps to full
	# narrow field while held, so either habit works.
	var z: float = maxf(zoom_level, 1.0 if Input.is_action_pressed("ciws_zoom") else 0.0)
	var want_fov: float = lerpf(FOV_WIDE, FOV_NARROW, z)
	camera.fov = lerpf(camera.fov, want_fov, clampf(delta * 8.0, 0.0, 1.0))

	# Reload.
	if reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			reloading = false
			ammo = MAGAZINE
			reload_finished.emit()
	elif Input.is_action_just_pressed("ciws_reload") and ammo < MAGAZINE:
		_start_reload()
	elif ammo <= 0:
		# Safety net: an empty gun always rearms itself. Without this, an
		# empty magazine outside the normal fire path leaves the mount dead.
		_start_reload()

	firing = (Input.is_action_pressed("ciws_fire") or force_fire) and ammo > 0 and not reloading

	if firing:
		spin = move_toward(spin, 1.0, delta / SPINUP_TIME)
	else:
		spin = move_toward(spin, 0.0, delta / SPINDOWN_TIME)

	# Slow barrel wander so the beaten zone drifts instead of sitting still.
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(0.15, 0.4)
		_wander_target = Vector2(randfn(0.0, 1.0), randfn(0.0, 1.0)) * deg_to_rad(wander_deg)
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

	if guided_weapons_enabled:
		_process_fire_control(delta)
	_update_audio()


func _start_reload() -> void:
	if reloading:
		return
	reloading = true
	_reload_timer = RELOAD_TIME
	reload_started.emit()


func _emit_round() -> void:
	ammo -= 1
	rounds_fired_total += 1

	var origin := muzzle.global_position
	var base := -muzzle.global_transform.basis.z

	# Dispersion: gaussian cone around the bore, plus the slow wander.
	var sigma := deg_to_rad(dispersion_deg)
	var yaw_off := randfn(0.0, sigma) + _wander.x
	var pitch_off := randfn(0.0, sigma) + _wander.y
	var right := base.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	var up := right.cross(base).normalized()
	var dir := (base + right * tan(yaw_off) + up * tan(pitch_off)).normalized()

	fired.emit(origin, dir * MUZZLE_VELOCITY)

	_flash_timer = 0.035
	_recoil = minf(_recoil + 0.05, 0.35)
	shake = minf(shake + SHAKE_PER_ROUND, SHAKE_CAP)


# ---------------------------------------------------------------------------
# Missile fire control
# ---------------------------------------------------------------------------

## True when the sensor is zoomed in far enough for the seeker to work.
func zoom_active() -> bool:
	return camera != null and camera.fov <= LOCK_ZOOM_FOV


func refill_missiles() -> void:
	missiles = MISSILE_CAPACITY
	_missile_regen_t = 0.0


## Called when the GUN kills something. Salvo charge is earned, and killing in
## quick succession earns it faster - that is the combo.
func add_combo_kill() -> void:
	combo += 1
	combo_timer = COMBO_WINDOW
	var mult: float = 1.0 + mini(combo, COMBO_MAX) * 0.14
	salvo_charge = clampf(salvo_charge + SALVO_CHARGE_PER_KILL * mult, 0.0, 1.0)


func salvo_ready() -> bool:
	return salvo_charge >= 1.0 and _salvo_queue.is_empty()


## True while a ripple is still leaving the cells.
func salvo_active() -> bool:
	return not _salvo_queue.is_empty()


func _process_fire_control(delta: float) -> void:
	# Cells rearm slowly on their own; a cleared wave tops them up.
	if missiles < MISSILE_CAPACITY:
		_missile_regen_t += delta
		if _missile_regen_t >= MISSILE_REGEN:
			_missile_regen_t = 0.0
			missiles += 1

	combo_timer = maxf(combo_timer - delta, 0.0)
	if combo_timer <= 0.0:
		combo = 0

	_refire_t = maxf(_refire_t - delta, 0.0)
	_run_salvo_queue(delta)
	_run_lock(delta)


# --- Single shot: zoom, hold the bore, wait for the tone -------------------

func _run_lock(delta: float) -> void:
	if lock_target != null and not is_instance_valid(lock_target):
		lock_target = null
		lock_progress = 0.0
	if not missile_input or not _enabled:
		_clear_lock()
		return
	if missiles <= 0:
		lock_denied_reason = "NO MISSILES"
		_clear_lock(true)
		return
	if not zoom_active():
		lock_denied_reason = "ZOOM TO LOCK"
		_clear_lock(true)
		return
	if _refire_t > 0.0:
		return

	var candidate := _best_lock_candidate()
	if candidate == null:
		lock_denied_reason = "NO TARGET"
		lock_progress = maxf(lock_progress - delta * 2.5, 0.0)
		if lock_progress <= 0.0:
			lock_target = null
		return

	lock_denied_reason = ""
	if candidate != lock_target:
		lock_target = candidate
		lock_progress = 0.0

	lock_progress = minf(lock_progress + delta / LOCK_TIME, 1.0)
	_lock_beeps(delta)

	if lock_progress >= 1.0:
		_fire_missile_at(lock_target)
		lock_progress = 0.0
		_refire_t = REFIRE_DELAY


func _clear_lock(keep_reason := false) -> void:
	lock_target = null
	lock_progress = 0.0
	if not keep_reason:
		lock_denied_reason = ""


## Closest contact to the bore inside the seeker cone.
func _best_lock_candidate() -> Enemy:
	var bore := -muzzle.global_transform.basis.z
	var eye := camera.global_position
	var best: Enemy = null
	var best_ang := LOCK_CONE_DEG
	for e in get_tree().get_nodes_in_group("enemy"):
		var en := e as Enemy
		if en == null or not en.alive or en.warping:
			continue
		var to: Vector3 = en.global_position - eye
		var d: float = to.length()
		if d < LOCK_MIN_RANGE or d > LOCK_MAX_RANGE:
			continue
		var ang: float = rad_to_deg(acos(clampf(bore.dot(to / d), -1.0, 1.0)))
		if ang < best_ang:
			best_ang = ang
			best = en
	return best


## Seeker chirp: the interval shrinks as the lock builds, then goes solid.
func _lock_beeps(delta: float) -> void:
	if lock_progress >= 1.0:
		return
	_lock_beep_t -= delta
	if _lock_beep_t <= 0.0:
		# Accelerating pip, the way a seeker tone tightens as it settles.
		# Floor is above the pip's own 0.10 s length so they never overlap
		# into a continuous tone before the lock is actually made.
		_lock_beep_t = lerpf(0.46, 0.125, lock_progress)
		if _lock_tone != null:
			_lock_audio.stream = _lock_tone
			_lock_audio.pitch_scale = lerpf(0.85, 1.35, lock_progress)
			_lock_audio.play()


# --- Special: multi-lock salvo ---------------------------------------------

## Locks every contact currently on screen and ripple-fires one cell at each.
## Returns the number of targets engaged, or 0 if it could not fire.
func request_salvo() -> int:
	if not guided_weapons_enabled or not _enabled or not salvo_ready():
		return 0
	var targets := visible_contacts()
	if targets.is_empty():
		return 0
	if targets.size() > SALVO_MAX_TARGETS:
		targets.resize(SALVO_MAX_TARGETS)

	salvo_targets = targets.duplicate()
	_salvo_queue.clear()
	var t := 0.0
	for tgt in targets:
		_salvo_queue.append({"target": tgt, "t": t})
		t += SALVO_RIPPLE
	_salvo_t = 0.0
	salvo_charge = 0.0
	salvo_started.emit(targets.size())
	return targets.size()


## Everything the sensor can currently see, worst threat first. The salvo does
## not need zoom, which is the whole point of it - it is the panic button.
func visible_contacts() -> Array:
	var out: Array = []
	if camera == null:
		return out
	for e in get_tree().get_nodes_in_group("enemy"):
		var en := e as Enemy
		if en == null or not en.alive or en.warping:
			continue
		if camera.is_position_behind(en.global_position):
			continue
		if not camera.is_position_in_frustum(en.global_position):
			continue
		if en.global_position.distance_to(camera.global_position) > LOCK_MAX_RANGE:
			continue
		out.append(en)
	out.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.threat * 60.0 - a.global_position.length() \
				> b.threat * 60.0 - b.global_position.length())
	return out


func _run_salvo_queue(delta: float) -> void:
	if _salvo_queue.is_empty():
		if not salvo_targets.is_empty():
			salvo_targets.clear()
		return
	_salvo_t += delta
	while not _salvo_queue.is_empty() and float(_salvo_queue[0]["t"]) <= _salvo_t:
		var entry: Dictionary = _salvo_queue.pop_front()
		var raw = entry["target"]
		if raw != null and is_instance_valid(raw) and (raw as Enemy).alive:
			_fire_missile_at(raw as Enemy, 0.22, false)


# --- Shared launch ---------------------------------------------------------

## `consume_cell` is false for salvo shots: the special is paid for with combo
## charge, not with the eight ready cells, so it still works when you are dry.
func _fire_missile_at(target: Enemy, spread := 0.06, consume_cell := true) -> void:
	if target == null:
		return
	var origin: Vector3 = launcher.global_position + Vector3(0, 0.9, 0)
	var fwd := -global_transform.basis.z
	var right := global_transform.basis.x
	# Straight up out of the cell, tipped slightly downrange, with a little
	# scatter so a ripple fans out instead of stacking.
	var dir := (Vector3.UP * 1.0
			+ fwd * 0.34
			+ right * randf_range(-spread, spread) * 3.0
			+ fwd * randf_range(-spread, spread) * 2.0).normalized()
	if consume_cell:
		missiles = maxi(missiles - 1, 0)
	if _lock_done != null:
		_lock_audio.stream = _lock_done
		_lock_audio.pitch_scale = 1.0
		_lock_audio.play()
	# Hard, short kick. Deliberately about twice the gun's sustained judder
	# (SHAKE_CAP) so a launch reads as a bigger event, and gone again inside
	# a fifth of a second.
	add_impulse(4.5)
	missile_launched.emit(origin, dir, target)


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
