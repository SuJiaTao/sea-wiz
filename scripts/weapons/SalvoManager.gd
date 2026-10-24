extends Node
class_name SalvoManager

enum RejectReason {
	DISABLED,
	ACTIVE,
	CHARGING,
	NO_TARGETS,
	LAUNCH_UNAVAILABLE,
}

signal started(target_count: int)
signal rejected(reason: RejectReason)

const CHARGE_PER_KILL: float = 0.085
const COMBO_WINDOW: float = 4.0
const COMBO_MAX: int = 12
const MAX_TARGETS: int = 12
const RIPPLE_INTERVAL: float = 0.11

@export var launcher: MissileLauncher
@export var enemies: EnemyManager

var charge: float = 0.0
var combo: int = 0
var combo_remaining: float = 0.0

var _enabled: bool = true
var _pending: Array[AbstractEnemy] = []
var _until_next_launch: float = 0.0


func set_enabled(value: bool) -> void:
	_enabled = value


func is_active() -> bool:
	return not _pending.is_empty()


func is_ready() -> bool:
	return charge >= 1.0 and not is_active()


func pending_targets() -> Array[AbstractEnemy]:
	var result: Array[AbstractEnemy] = []
	for enemy in _pending:
		if _can_target(enemy):
			result.append(enemy)
	return result


func on_enemy_killed(
	_enemy: AbstractEnemy,
	weapon_source: DamageSource
) -> void:
	if not _enabled or get_tree().paused:
		return
	if weapon_source == null or not weapon_source.charges_salvo:
		return

	combo += 1
	combo_remaining = COMBO_WINDOW
	var multiplier := 1.0 + mini(combo, COMBO_MAX) * 0.14
	charge = clampf(charge + CHARGE_PER_KILL * multiplier, 0.0, 1.0)


func request_salvo() -> void:
	if not _enabled or get_tree().paused:
		rejected.emit(RejectReason.DISABLED)
		return
	if is_active():
		rejected.emit(RejectReason.ACTIVE)
		return
	if not is_ready():
		rejected.emit(RejectReason.CHARGING)
		return

	var targets := _select_targets()
	if targets.is_empty():
		rejected.emit(RejectReason.NO_TARGETS)
		return

	var target_count := targets.size()
	_pending = targets
	if not launcher.try_launch_salvo(_pending[0]):
		_pending.clear()
		rejected.emit(RejectReason.LAUNCH_UNAVAILABLE)
		return

	_pending.pop_front()
	charge = 0.0
	_until_next_launch = RIPPLE_INTERVAL
	started.emit(target_count)


func _physics_process(delta: float) -> void:
	if not _enabled:
		return

	combo_remaining = maxf(combo_remaining - delta, 0.0)
	if combo_remaining <= 0.0:
		combo = 0

	if _pending.is_empty():
		return
	_until_next_launch -= delta
	if _until_next_launch > 0.0:
		return

	while not _pending.is_empty():
		var target: AbstractEnemy = _pending[0]
		if not _can_target(target):
			_pending.pop_front()
			continue
		if launcher.try_launch_salvo(target):
			_pending.pop_front()
			_until_next_launch = RIPPLE_INTERVAL
		return


func _select_targets() -> Array[AbstractEnemy]:
	var camera := launcher.turret.camera
	var origin := camera.global_position
	var maximum_squared := MissileLauncher.MAX_RANGE * MissileLauncher.MAX_RANGE
	var result: Array[AbstractEnemy] = []

	for enemy in enemies.live_enemies():
		if enemy.contact_kind == AbstractEnemy.ContactKind.MISSILE:
			continue
		if enemy.global_position.distance_squared_to(origin) > maximum_squared:
			continue
		if not camera.is_position_in_frustum(enemy.global_position):
			continue
		result.append(enemy)

	result.sort_custom(func(a: AbstractEnemy, b: AbstractEnemy) -> bool:
		return (
			a.global_position.distance_squared_to(origin)
			< b.global_position.distance_squared_to(origin)
		)
	)
	if result.size() > MAX_TARGETS:
		result.resize(MAX_TARGETS)
	return result


func _can_target(enemy: AbstractEnemy) -> bool:
	return (
		is_instance_valid(enemy)
		and enemy.alive
		and enemy.hp > 0.0
		and not enemy.is_queued_for_deletion()
		and not enemy._destroy_requested
	)
