extends Node
class_name MissileLauncher

enum LaunchMode { SINGLE, SALVO }

signal launched(origin: Vector3, target: AbstractEnemy, mode: LaunchMode)
signal detonated(position: Vector3, radius: float)

const CAPACITY: int = 8
const REARM_TIME: float = 9.0
const LOCK_TIME := Vector2(0.8, 1.3)
const NO_TARGET_REASON := "NO TARGET"
const GUN_TARGET_REASON := "GUNS ONLY"
const LOCK_CONE_DEG: float = 3.2
const MIN_RANGE: float = 130.0
const MAX_RANGE: float = 2800.0
const LOCK_ZOOM_FOV: float = 38.0
const REFIRE_TIME: float = 0.55

@export var turret: Turret
@export var enemies: EnemyManager
@export var ballistics: BallisticManager
@export var renderer: ProjectileBatch
@export var smoke: MissileSmokeRenderer
@export var damage_source: DamageSource

var missiles: int = CAPACITY
var lock_target: AbstractEnemy
var lock_progress: float = 0.0
var lock_denied_reason: String = ""
var trigger_held: bool = false

var _enabled: bool = true
var _rearm_elapsed: float = 0.0
var _refire_remaining: float = 0.0
var _lock_duration: float = LOCK_TIME.y


func _ready() -> void:
	renderer.sensor = turret.camera
	smoke.sensor = turret.camera


func set_enabled(value: bool) -> void:
	_enabled = value
	if not value:
		set_trigger(false)


func set_trigger(held: bool) -> void:
	trigger_held = held and _enabled
	if not trigger_held:
		_clear_lock()


func refill() -> void:
	missiles = CAPACITY
	_rearm_elapsed = 0.0


func _physics_process(delta: float) -> void:
	if not _enabled:
		return

	if missiles < CAPACITY:
		_rearm_elapsed += delta
		if _rearm_elapsed >= REARM_TIME:
			_rearm_elapsed -= REARM_TIME
			missiles += 1
	else:
		_rearm_elapsed = 0.0

	_refire_remaining = maxf(_refire_remaining - delta, 0.0)
	_run_lock(delta)


func _run_lock(delta: float) -> void:
	if not trigger_held:
		_clear_lock()
		return
	if missiles <= 0:
		_clear_lock("NO MISSILES")
		return
	if turret.camera.fov > LOCK_ZOOM_FOV:
		_clear_lock("ZOOM TO LOCK")
		return
	if _refire_remaining > 0.0:
		_clear_lock()
		return

	var candidate := _best_candidate()
	if candidate == null:
		lock_denied_reason = GUN_TARGET_REASON if _missile_in_cone() else NO_TARGET_REASON
		lock_progress = maxf(lock_progress - delta * 2.5, 0.0)
		if lock_progress <= 0.0 or not is_instance_valid(lock_target):
			lock_target = null
		return

	lock_denied_reason = ""
	if candidate != lock_target:
		lock_target = candidate
		lock_progress = 0.0
		_lock_duration = randf_range(LOCK_TIME.x, LOCK_TIME.y)

	lock_progress = minf(lock_progress + delta / _lock_duration, 1.0)
	if lock_progress >= 1.0:
		if try_launch(lock_target):
			_clear_lock()
			_refire_remaining = REFIRE_TIME
		else:
			lock_denied_reason = "LAUNCH UNAVAILABLE"


func _clear_lock(reason: String = "") -> void:
	lock_target = null
	lock_progress = 0.0
	lock_denied_reason = reason


func _best_candidate() -> AbstractEnemy:
	var forward := -turret.muzzle.global_basis.z
	var origin := turret.camera.global_position
	var best: AbstractEnemy
	var best_angle := LOCK_CONE_DEG

	for enemy in enemies.live_enemies():
		if enemy.contact_kind == AbstractEnemy.ContactKind.MISSILE:
			continue
		var offset := enemy.global_position - origin
		var distance := offset.length()
		if distance < MIN_RANGE or distance > MAX_RANGE:
			continue
		var angle := rad_to_deg(acos(clampf(
			forward.dot(offset / distance), -1.0, 1.0
		)))
		if angle < best_angle:
			best_angle = angle
			best = enemy
	return best


func _missile_in_cone() -> bool:
	var forward := -turret.muzzle.global_basis.z
	var origin := turret.camera.global_position
	for enemy in enemies.live_enemies():
		if enemy.contact_kind != AbstractEnemy.ContactKind.MISSILE:
			continue
		var direction := (enemy.global_position - origin).normalized()
		if rad_to_deg(forward.angle_to(direction)) < LOCK_CONE_DEG:
			return true
	return false


func try_launch(target: AbstractEnemy) -> bool:
	return _try_launch(target, LaunchMode.SINGLE)


func try_launch_salvo(target: AbstractEnemy) -> bool:
	return _try_launch(target, LaunchMode.SALVO)


func _try_launch(target: AbstractEnemy, mode: LaunchMode) -> bool:
	if not _enabled or get_tree().paused:
		return false
	if mode == LaunchMode.SINGLE and missiles <= 0:
		return false
	if not is_instance_valid(target):
		return false
	if (
		not target.alive
		or target.hp <= 0.0
		or target.is_queued_for_deletion()
		or target._destroy_requested
	):
		return false

	var origin := turret.launcher.global_position + Vector3(0, 0.9, 0)
	var forward := -turret.global_basis.z
	var right := turret.global_basis.x
	var spread := 0.22 if mode == LaunchMode.SALVO else 0.06
	var direction := (
		Vector3.UP
		+ forward * 0.34
		+ right * randf_range(-spread, spread) * 3.0
		+ forward * randf_range(-spread, spread) * 2.0
	).normalized()

	var projectile := MissileProjectile.new(
		renderer, smoke, ballistics, origin, direction, target
	)
	projectile.weapon_source = damage_source
	projectile.detonated.connect(_on_detonated)
	if not ballistics.fire(projectile):
		return false

	if mode == LaunchMode.SINGLE:
		missiles -= 1
	launched.emit(origin, target, mode)
	return true


func _on_detonated(position: Vector3, radius: float) -> void:
	detonated.emit(position, radius)
