extends Node
class_name MissileLauncher

enum LaunchMode { SINGLE, SALVO }

signal launched(origin: Vector3, target: AbstractEnemy, mode: LaunchMode)
signal detonated(position: Vector3, radius: float)
## A missile is committed to a target the moment the trigger is pulled on a lock.
signal committed(target: AbstractEnemy)

const CAPACITY: int = 8
const REARM_TIME: float = 9.0
const NO_TARGET_REASON := "NO TARGET"
const GUN_TARGET_REASON := "GUNS ONLY"
const RANGE_REASON := "OUT OF RANGE"
const LOCK_CONE_DEG: float = 3.2
const MIN_RANGE: float = 130.0
const MAX_RANGE: float = 2800.0
const REFIRE_TIME: float = 0.25
const VERTICAL_CLIMB: float = 0.75
const CELL_EXIT: float = 1.2
const EXHAUST_LEAD: float = 0.05
const UPTAKE_FLAMES: int = 8
const UPTAKE_FLAME_SPEED := Vector2(1.0, 4.0)
const UPTAKE_FLAME_RISE: float = 16.0
const UPTAKE_FLAME_SIZE: float = 0.4
const UPTAKE_PUFFS: int = 5
const UPTAKE_SMOKE_RISE: float = 9.0
const UPTAKE_SMOKE_SIZE: float = 0.6
const LAUNCH_FLAMES: int = 10
const LAUNCH_FLAME_SPEED := Vector2(2.0, 7.0)
const LAUNCH_FLAME_SIZE: float = 0.5
const LAUNCH_SPARKS: int = 14
const DECK_SMOKE_JETS: int = 6
const DECK_SMOKE_PUFFS: int = 2
const DECK_SMOKE_SPEED := Vector2(1.0, 3.0)
const DECK_SMOKE_SPREAD: float = 4.0
const DECK_SMOKE_SIZE: float = 0.6
const ROW_TOLERANCE: float = 0.2

@export var turret: Turret
@export var fire_control: FireControl
@export var enemies: EnemyManager
@export var ballistics: BallisticManager
@export var renderer: ProjectileBatch
@export var smoke: MissileSmokeRenderer
@export var damage_source: DamageSource
@export var cells: VLSLauncher
@export var fx: FXManager
@export var effects: EffectManager

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
var _firing_order: Array[int] = []
var _order_index: int = 0
var _emerging: Array[Array] = []
var _in_flight: Array[MissileProjectile] = []


func _ready() -> void:
	renderer.sensor = turret.camera
	smoke.sensor = turret.camera
	if cells != null:
		cells.cell_ready.connect(_on_cell_ready)
		_firing_order = _front_row_first()


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


## Everything one of our missiles is on its way to, including missiles still
## waiting in an opening cell. A target drops off once its missile hits,
## misses or is pulled away by a flare.
func homing_targets() -> Array[AbstractEnemy]:
	var targets: Array[AbstractEnemy] = []
	for missile in _in_flight:
		_add_target(targets, missile.homing_target())
	for waiting: Array in _waiting.values():
		_add_target(targets, waiting[0])
	for launch: Array in _emerging:
		_add_target(targets, launch[3])
	return targets


func _add_target(targets: Array[AbstractEnemy], wanted: Variant) -> void:
	if is_instance_valid(wanted) and (wanted as AbstractEnemy).alive and not targets.has(wanted):
		targets.append(wanted as AbstractEnemy)


func _physics_process(delta: float) -> void:
	var guiding: Array[MissileProjectile] = []
	for missile in _in_flight:
		if missile.homing_target() != null:
			guiding.append(missile)
	_in_flight = guiding
	_process_emerging(delta)
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
		committed.emit(lock_target)
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
		var cell := _open_next_cell()
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
	_in_flight.append(projectile)
	return projectile


## Cells fire front row first, port to starboard: left to right, top to
## bottom as the launcher is seen from the gun.
func _front_row_first() -> Array[int]:
	var ship := cells.get_parent() as Node3D
	var order: Array[int] = []
	for cell in cells.cell_count():
		order.append(cell)
	var place := func(cell: int) -> Vector3:
		return ship.global_transform.affine_inverse() * cells.cell_world_position(cell)
	order.sort_custom(func(a: int, b: int) -> bool:
		var pa: Vector3 = place.call(a)
		var pb: Vector3 = place.call(b)
		if absf(pa.z - pb.z) > ROW_TOLERANCE:
			return pa.z < pb.z
		return pa.x < pb.x
	)
	return order


func _open_next_cell() -> int:
	for step in _firing_order.size():
		var cell := _firing_order[(_order_index + step) % _firing_order.size()]
		if cells.launch(cell) >= 0:
			_order_index = (_order_index + step + 1) % _firing_order.size()
			return cell
	return -1


## The lid is open: the motor lights, its exhaust is ducted back up out of the
## module's hatch, and a moment later the missile bursts out of the cell.
func _on_cell_ready(cell: int, launch_position: Vector3, up: Vector3) -> void:
	var waiting: Array = _waiting.get(cell, [])
	_waiting.erase(cell)
	var uptake := cells.uptake_world_position(cell)
	effects.fireballs.burst(uptake, UPTAKE_FLAMES, UPTAKE_FLAME_SPEED, UPTAKE_FLAME_SIZE, up * UPTAKE_FLAME_RISE)
	effects.smoke.burst(uptake, UPTAKE_PUFFS, UPTAKE_FLAME_SPEED, UPTAKE_SMOKE_SIZE, up * UPTAKE_SMOKE_RISE)
	fx.hit(launch_position)
	if waiting.is_empty():
		return
	_emerging.append([EXHAUST_LEAD, launch_position, up, waiting[0], waiting[1]])


func _process_emerging(delta: float) -> void:
	for index in range(_emerging.size() - 1, -1, -1):
		var launch: Array = _emerging[index]
		launch[0] -= delta
		if launch[0] > 0.0:
			continue
		_emerging.remove_at(index)
		_burst_out(launch[1], launch[2], launch[3], launch[4])


func _burst_out(launch_position: Vector3, up: Vector3, wanted: Variant, mode: LaunchMode) -> void:
	effects.fireballs.burst(launch_position, LAUNCH_FLAMES, LAUNCH_FLAME_SPEED, LAUNCH_FLAME_SIZE, up * UPTAKE_FLAME_RISE)
	fx.spark_burst(launch_position, LAUNCH_SPARKS)
	for jet in DECK_SMOKE_JETS:
		var out := Vector3.RIGHT.rotated(Vector3.UP, TAU * jet / DECK_SMOKE_JETS)
		effects.smoke.burst(launch_position, DECK_SMOKE_PUFFS, DECK_SMOKE_SPEED, DECK_SMOKE_SIZE, out * DECK_SMOKE_SPREAD)
	var target: AbstractEnemy = null
	if is_instance_valid(wanted):
		target = wanted
	if target == null or not target.alive:
		target = fire_control.locked if fire_control.is_locked() else null
	if target == null:
		return
	var origin := launch_position + up * CELL_EXIT
	var projectile := _missile(origin, up, target)
	projectile.vertical_climb = VERTICAL_CLIMB
	if ballistics.fire(projectile):
		launched.emit(origin, target, mode)


func _on_detonated(position: Vector3, radius: float) -> void:
	detonated.emit(position, radius)
