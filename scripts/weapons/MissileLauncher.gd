extends Node
class_name MissileLauncher

enum LaunchMode { SINGLE, SALVO }

signal launched(origin: Vector3, target: AbstractEnemy, mode: LaunchMode)
signal detonated(position: Vector3, radius: float)

const CAPACITY: int = 8
const REARM_TIME: float = 9.0
const NO_TARGET_REASON := "NO TARGET"
const GUN_TARGET_REASON := "GUNS ONLY"
const RANGE_REASON := "OUT OF RANGE"
const LOCK_CONE_DEG: float = 3.2
const MIN_RANGE: float = 130.0
const MAX_RANGE: float = 2800.0
const REFIRE_TIME: float = 0.55
const VERTICAL_CLIMB: float = 0.75
const CELL_EXIT: float = 1.2
const IGNITION_PUFFS: int = 40
const IGNITION_SPEED := Vector2(3.0, 11.0)
const IGNITION_SPARKS: int = 12

@export var turret: Turret
@export var fire_control: FireControl
@export var enemies: EnemyManager
@export var ballistics: BallisticManager
@export var renderer: ProjectileBatch
@export var smoke: MissileSmokeRenderer
@export var damage_source: DamageSource
@export var cells: VLSLauncher
@export var fx: FXManager

var missiles: int = CAPACITY
var lock_target: AbstractEnemy
var lock_progress: float = 0.0
var lock_denied_reason: String = ""
var trigger_held: bool = false

var _enabled: bool = true
var _rearm_elapsed: float = 0.0
var _fired_this_pull: bool = false
var _refire_remaining: float = 0.0
var _waiting: Dictionary[int, Array] = {}


func _ready() -> void:
	renderer.sensor = turret.camera
	smoke.sensor = turret.camera
	if cells != null:
		cells.cell_ready.connect(_on_cell_ready)


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


func _run_lock(_delta: float) -> void:
	if not trigger_held:
		_clear_lock()
		_fired_this_pull = false
		return
	if missiles <= 0:
		_clear_lock("NO MISSILES")
		return
	if not fire_control.is_locked():
		_clear_lock(GUN_TARGET_REASON if _missile_in_cone() else NO_TARGET_REASON)
		return
	lock_target = fire_control.locked
	lock_progress = 1.0
	lock_denied_reason = ""
	if _refire_remaining > 0.0 or _fired_this_pull:
		return
	var reach := fire_control.lock_range()
	if reach < MIN_RANGE or reach > MAX_RANGE:
		lock_denied_reason = RANGE_REASON
	elif try_launch(lock_target):
		_refire_remaining = REFIRE_TIME
		_fired_this_pull = true
	else:
		lock_denied_reason = "LAUNCH UNAVAILABLE"


func _clear_lock(reason: String = "") -> void:
	lock_target = null
	lock_progress = 0.0
	lock_denied_reason = reason


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

	if cells != null:
		var cell := cells.launch()
		if cell < 0:
			return false
		_waiting[cell] = [target, mode]
		if mode == LaunchMode.SINGLE:
			missiles -= 1
		return true
	var projectile := _missile(origin, direction, target)
	if not ballistics.fire(projectile):
		return false

	if mode == LaunchMode.SINGLE:
		missiles -= 1
	launched.emit(origin, target, mode)
	return true


func _missile(origin: Vector3, direction: Vector3, target: AbstractEnemy) -> MissileProjectile:
	var projectile := MissileProjectile.new(
		renderer, smoke, ballistics, origin, direction, target
	)
	projectile.weapon_source = damage_source
	projectile.detonated.connect(_on_detonated)
	return projectile


func _on_cell_ready(cell: int, launch_position: Vector3, up: Vector3) -> void:
	var waiting: Array = _waiting.get(cell, [])
	_waiting.erase(cell)
	smoke.burst(launch_position, IGNITION_PUFFS, IGNITION_SPEED)
	fx.spark_burst(launch_position, IGNITION_SPARKS)
	if waiting.is_empty():
		return
	var target: AbstractEnemy = null
	if is_instance_valid(waiting[0]):
		target = waiting[0]
	if target == null or not target.alive:
		target = fire_control.locked if fire_control.is_locked() else null
	if target == null:
		return
	var origin := launch_position + up * CELL_EXIT
	var projectile := _missile(origin, up, target)
	projectile.vertical_climb = VERTICAL_CLIMB
	if ballistics.fire(projectile):
		launched.emit(origin, target, waiting[1])


func _on_detonated(position: Vector3, radius: float) -> void:
	detonated.emit(position, radius)
