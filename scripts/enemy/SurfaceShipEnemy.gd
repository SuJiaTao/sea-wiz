extends AbstractEnemy
class_name SurfaceShipEnemy

# An enemy warship on the horizon. It sails broadside to us and holds its fire
# for a while, then shells us with its gun and launches anti-ship missiles.
# Each heavy hit past a threshold starts another fire on board.

signal fire_started(spot: Node3D, strength: float)

const GRAVITY: float = 9.81
const BURN_THRESHOLDS: Array[float] = [0.8, 0.55, 0.3]
const FIRE_STRENGTH: float = 0.6
const MISSILE_LIFT := Vector3(0.0, 6.0, 0.0)
const FLASH_FADE_PER_SECOND: float = 6.0
const FLASH_GLOW_SIZE: float = 4.0
const ROLL_AMOUNT: float = 0.02
const ROLL_RATE: float = 0.45

@export var cruise_speed: float = 7.0
@export var target_position := Vector3.ZERO
@export var hold_fire_time: float = 14.0
@export var gun_interval: float = 5.5
@export var shells_per_volley: int = 2
@export var volley_gap: float = 0.6
@export var shell_scene: PackedScene
@export var shell_speed: float = 420.0
@export var shell_spread: float = 80.0
@export var missile_interval: float = 18.0
@export var missile_scene: PackedScene
@export var gun: Node3D
@export var launcher: Node3D
@export var flash_light: OmniLight3D
@export var flash_glow: Node3D
@export var fire_spots: Node3D
@export var flash_energy: float = 12.0

var _gun_clock: float = 0.0
var _missile_clock: float = 0.0
var _shells_queued: int = 0
var _gap_clock: float = 0.0
var _flash: float = 0.0
var _fires_lit: int = 0
var _age: float = 0.0

@onready var _hurtbox: Area3D = $Hurtbox


func _create() -> void:
	_hurtbox.collision_layer = COLLISION_LAYER
	var toward := _flat(target_position - global_position)
	var course := toward.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
	velocity = course * cruise_speed
	look_at(global_position + course, Vector3.UP)
	_gun_clock = hold_fire_time + randf() * gun_interval
	_missile_clock = hold_fire_time + randf_range(0.5, 1.0) * missile_interval
	_age = randf() * TAU


func _on_think(delta: float) -> void:
	_age += delta
	global_position += velocity * delta
	if visuals != null:
		visuals.rotation.z = sin(_age * ROLL_RATE) * ROLL_AMOUNT
	# Holds fire while it sits behind the bridge, where we cannot answer.
	if not BlindArc.contains(global_position):
		_run_gun(delta)
		_run_missiles(delta)
	_fade_flash(delta)


func _run_gun(delta: float) -> void:
	_gun_clock -= delta
	if _gun_clock <= 0.0 and shell_scene != null:
		_gun_clock = gun_interval
		_shells_queued = shells_per_volley
		_gap_clock = 0.0
	if _shells_queued <= 0:
		return
	_gap_clock -= delta
	if _gap_clock > 0.0:
		return
	_gap_clock = volley_gap
	_shells_queued -= 1
	_fire_shell()


func _fire_shell() -> void:
	var muzzle := gun.global_position
	var spread := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * shell_spread
	var aim := target_position + Vector3(spread.x, 0.0, spread.y)
	var shell := shell_scene.instantiate() as BombEnemy
	shell.target_position = aim
	shell.velocity = _lob(muzzle, aim)
	weapon_launched.emit(shell, Transform3D(Basis.IDENTITY, muzzle))
	_flash = 1.0


## Low-angle firing solution that lands a shell at speed on the aim point.
func _lob(from: Vector3, to: Vector3) -> Vector3:
	var flat := _flat(to - from)
	var reach := Vector2(to.x - from.x, to.z - from.z).length()
	var lift := clampf(GRAVITY * reach / (shell_speed * shell_speed), 0.0, 1.0)
	var elevation := 0.5 * asin(lift)
	return (flat * cos(elevation) + Vector3.UP * sin(elevation)) * shell_speed


func _run_missiles(delta: float) -> void:
	_missile_clock -= delta
	if _missile_clock > 0.0 or missile_scene == null:
		return
	_missile_clock = missile_interval
	var missile := missile_scene.instantiate() as FlyingEnemy
	missile.target_position = target_position
	missile.velocity = _flat(target_position - launcher.global_position)
	weapon_launched.emit(missile, Transform3D(Basis.IDENTITY, launcher.global_position + MISSILE_LIFT))
	_flash = maxf(_flash, 0.6)


func _fade_flash(delta: float) -> void:
	_flash = maxf(_flash - FLASH_FADE_PER_SECOND * delta, 0.0)
	if flash_light != null:
		flash_light.global_position = gun.global_position
		flash_light.light_energy = flash_energy * _flash
	if flash_glow != null:
		flash_glow.visible = _flash > 0.0
		flash_glow.scale = Vector3.ONE * maxf(FLASH_GLOW_SIZE * _flash, 0.01)


func _on_damage(_amount: float, _world_point: Vector3) -> void:
	var left := hp / max_hp
	while _fires_lit < BURN_THRESHOLDS.size() and left < BURN_THRESHOLDS[_fires_lit]:
		var spot := fire_spots.get_child(_fires_lit % fire_spots.get_child_count()) as Node3D
		fire_started.emit(spot, FIRE_STRENGTH)
		_fires_lit += 1


func burning_spots() -> Array[Node3D]:
	var spots: Array[Node3D] = []
	for child in fire_spots.get_children():
		spots.append(child as Node3D)
	return spots


func _flat(direction: Vector3) -> Vector3:
	return Vector3(direction.x, 0.0, direction.z).normalized()


func _on_destroy() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.collision_layer = 0
