extends AbstractDeckWeapon
class_name DeckCannon
## A slow bow gun slaved to the CIWS sight. It aims at the point the
## sight is looking at, not along the sight, so the two lines cross.

signal fired(origin: Vector3)
signal detonated(position: Vector3, radius: float)

const SHELL_SPEED: float = 560.0
const RELOAD_TIME: float = 2.6
const TRAIN_RATE: float = deg_to_rad(38.0)
const ELEVATE_RATE: float = deg_to_rad(24.0)
const MIN_ELEVATION: float = deg_to_rad(-5.0)
const MAX_ELEVATION: float = deg_to_rad(70.0)
const DEFAULT_RANGE: float = 1500.0
const ACQUIRE_CONE_DEG: float = 5.0
const ON_TARGET_DEG: float = 2.0
const GRAVITY: float = 9.81
const MUZZLE_SHAKE: float = 2.2
const BLAST_SHAKE: float = 1.2
const BLAST_VISUAL_SCALE: float = 0.7

@export var turret: Turret
@export var enemies: EnemyManager
@export var ballistics: BallisticManager
@export var tracers: ProjectileBatch
@export var fx: FXManager
@export var damage_source: DamageSource
@export var mount: Node3D
@export var barrel: Node3D
@export var muzzle: Marker3D

var reload_left: float = 0.0
var aim_point: Vector3
var on_target: bool = false

func _action() -> StringName:
	return &"ciws_cannon"


func _trigger() -> void:
	request_fire()


func request_fire() -> bool:
	if not _enabled or reload_left > 0.0:
		return false
	reload_left = RELOAD_TIME
	var origin := muzzle.global_position
	var forward := -muzzle.global_basis.z
	var shell := ShellProjectile.new(
		tracers, ballistics, origin, forward * SHELL_SPEED
	)
	shell.weapon_source = damage_source
	shell.detonated.connect(_on_detonated)
	ballistics.fire(shell)
	fx.hit(origin)
	turret.apply_camera_shake_impulse(MUZZLE_SHAKE)
	fired.emit(origin)
	return true


func _physics_process(delta: float) -> void:
	reload_left = maxf(reload_left - delta, 0.0)
	aim_point = _sight_point()
	var target := _with_drop(aim_point)
	var local := mount.get_parent_node_3d().to_local(target)
	var offset := local - mount.position
	var yaw := atan2(-offset.x, -offset.z)
	mount.rotation.y = _approach_angle(
		mount.rotation.y, yaw, TRAIN_RATE * delta
	)
	var flat := Vector2(offset.x, offset.z).length()
	var pitch := clampf(atan2(offset.y, flat), MIN_ELEVATION, MAX_ELEVATION)
	barrel.rotation.x = move_toward(
		barrel.rotation.x, pitch, ELEVATE_RATE * delta
	)
	var bore := -muzzle.global_basis.z
	var wanted := (target - muzzle.global_position).normalized()
	on_target = rad_to_deg(bore.angle_to(wanted)) <= ON_TARGET_DEG


func _sight_point() -> Vector3:
	var camera := turret.camera
	var eye := camera.global_position
	var sight := -camera.global_basis.z
	var best_range := DEFAULT_RANGE
	var best_angle := ACQUIRE_CONE_DEG
	var best: AbstractEnemy = null
	for enemy in enemies.live_enemies():
		var offset := enemy.global_position - eye
		var angle := rad_to_deg(sight.angle_to(offset))
		if angle < best_angle:
			best_angle = angle
			best_range = offset.length()
			best = enemy
	if best == null:
		return eye + sight * best_range
	var flight := best_range / SHELL_SPEED
	return best.global_position + best.velocity * flight


func _with_drop(point: Vector3) -> Vector3:
	var flight := muzzle.global_position.distance_to(point) / SHELL_SPEED
	return point + Vector3.UP * (0.5 * GRAVITY * flight * flight)


func _approach_angle(current: float, target: float, step: float) -> float:
	var difference := wrapf(target - current, -PI, PI)
	return wrapf(current + clampf(difference, -step, step), -PI, PI)


func _on_detonated(position: Vector3, radius: float) -> void:
	fx.explosion(position, radius * BLAST_VISUAL_SCALE)
	turret.apply_camera_shake_impulse(BLAST_SHAKE)
	detonated.emit(position, radius)
