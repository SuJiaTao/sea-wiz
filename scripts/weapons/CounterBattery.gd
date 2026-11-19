extends AbstractDeckWeapon
class_name CounterBattery

# The launcher behind the bridge. One press marks every threat in view, holds
# the marks a moment while the fire control settles, then ripples a missile
# off the stern at each of them.

signal designated(targets: Array[AbstractEnemy])

const MARK_TIME: float = 0.8
const RIPPLE_GAP: float = 0.09
const COOLDOWN: float = 22.0
const MAX_TARGETS: int = 12
const MAX_RANGE: float = 5000.0
const CLIMB_TIME: float = 0.7
const CELL_SPREAD: float = 1.6
const LAUNCH_FLAMES: int = 8
const LAUNCH_FLAME_SPEED := Vector2(2.0, 6.0)
const LAUNCH_FLAME_SIZE: float = 0.45
const BLAST_VISUAL_SCALE: float = 0.55

@export var turret: Turret
@export var enemies: EnemyManager
@export var ballistics: BallisticManager
@export var renderer: ProjectileBatch
@export var smoke: MissileSmokeRenderer
@export var damage_source: DamageSource
@export var effects: EffectManager
@export var fx: FXManager
@export var cells: Node3D

var marked: Array[AbstractEnemy] = []
var cooldown_left: float = 0.0

var _mark_left: float = 0.0
var _ripple_left: float = 0.0
var _queue: Array[AbstractEnemy] = []


func _trigger() -> void:
	if cooldown_left > 0.0 or _mark_left > 0.0 or not _queue.is_empty():
		return
	marked = _threats_in_view()
	if marked.is_empty():
		return
	cooldown_left = COOLDOWN
	_mark_left = MARK_TIME
	designated.emit(marked)


func readiness() -> float:
	return 1.0 - cooldown_left / COOLDOWN


func restock() -> void:
	cooldown_left = 0.0


func is_marking() -> bool:
	return _mark_left > 0.0


func _threats_in_view() -> Array[AbstractEnemy]:
	var camera := turret.camera
	var found: Array[AbstractEnemy] = []
	for enemy in enemies.live_enemies():
		if not camera.is_position_in_frustum(enemy.global_position):
			continue
		if enemy.global_position.distance_to(camera.global_position) > MAX_RANGE:
			continue
		found.append(enemy)
	var eye := camera.global_position
	found.sort_custom(func(a: AbstractEnemy, b: AbstractEnemy) -> bool:
		return a.global_position.distance_squared_to(eye) < b.global_position.distance_squared_to(eye)
	)
	return found.slice(0, MAX_TARGETS)


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	var standing: Array[AbstractEnemy] = []
	for enemy: Variant in marked:
		if is_instance_valid(enemy) and (enemy as AbstractEnemy).alive:
			standing.append(enemy)
	marked = standing
	if _mark_left > 0.0:
		_mark_left -= delta
		if _mark_left <= 0.0:
			_queue = marked.duplicate()
			_ripple_left = 0.0
		return
	if _queue.is_empty():
		return
	_ripple_left -= delta
	if _ripple_left > 0.0:
		return
	_ripple_left = RIPPLE_GAP
	var target: Variant = _queue.pop_front()
	if is_instance_valid(target) and (target as AbstractEnemy).alive:
		_launch(target as AbstractEnemy)
	if _queue.is_empty():
		marked.clear()


func _launch(target: AbstractEnemy) -> void:
	var origin := cells.global_position + cells.global_basis.x * randf_range(-CELL_SPREAD, CELL_SPREAD)
	var missile := MissileProjectile.new(renderer, smoke, ballistics, origin, Vector3.UP, target)
	missile.vertical_climb = CLIMB_TIME
	missile.weapon_source = damage_source
	missile.detonated.connect(_on_detonated)
	ballistics.fire(missile)
	effects.fireballs.burst(origin, LAUNCH_FLAMES, LAUNCH_FLAME_SPEED, LAUNCH_FLAME_SIZE, Vector3.DOWN)


func _on_detonated(position: Vector3, radius: float) -> void:
	fx.explosion(position, radius * BLAST_VISUAL_SCALE)
