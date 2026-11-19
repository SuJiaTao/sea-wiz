extends AbstractDeckWeapon
class_name DeckCannon

# The twin gun on the foredeck. It follows the CIWS sight, and each shot fires
# both barrels a moment apart with explosive shells that burst near the target.

signal fired(origin: Vector3)
signal detonated(position: Vector3, radius: float)

const SHELL_SPEED: float = 560.0
const RELOAD_TIME: float = 2.6
const SECOND_BARREL_DELAY: float = 0.18
const DEFAULT_RANGE: float = 1500.0
const SHIP_AIM_HEIGHT: float = 6.0
const MUZZLES: Array[Vector3] = [Vector3(-0.86, 0.0, -8.45), Vector3(0.86, 0.0, -8.45)]
const MUZZLE_SHAKE: float = 2.2
const BLAST_SHAKE: float = 1.2
const BLAST_VISUAL_SCALE: float = 0.7

@export var turret: Turret
@export var fire_control: FireControl
@export var ballistics: BallisticManager
@export var tracers: ProjectileBatch
@export var fx: FXManager
@export var damage_source: DamageSource
@export var gun: DeckGunTurret
## When set, the gun fires on its own at the enemy ship in the sight.
@export var gunnery: SurfaceGunnery

var reload_left: float = 0.0
var aim_point: Vector3

var _second_in: float = -1.0


func _trigger() -> void:
	request_fire()


func request_fire() -> bool:
	if not _enabled or reload_left > 0.0:
		return false
	reload_left = RELOAD_TIME
	_fire_barrel(MUZZLES[0])
	_second_in = SECOND_BARREL_DELAY
	return true


func readiness() -> float:
	return 1.0 - reload_left / RELOAD_TIME


func fall_of_shot() -> Vector3:
	var origin := gun.barrel_point(Vector3.ZERO)
	return origin + gun.muzzle_direction() * origin.distance_to(aim_point)


func _fire_barrel(muzzle: Vector3) -> void:
	var origin := gun.barrel_point(muzzle)
	var shell := ShellProjectile.new(
		tracers, ballistics, origin, gun.muzzle_direction() * SHELL_SPEED
	)
	shell.weapon_source = damage_source
	shell.detonated.connect(_on_detonated)
	ballistics.fire(shell)
	gun.fire()
	fx.hit(origin)
	turret.apply_camera_shake_impulse(MUZZLE_SHAKE)
	fired.emit(origin)


func _physics_process(delta: float) -> void:
	reload_left = maxf(reload_left - delta, 0.0)
	if _second_in >= 0.0:
		_second_in -= delta
		if _second_in < 0.0:
			_fire_barrel(MUZZLES[1])
	if not _enabled:
		gun.park()
		on_target = false
		return
	if gunnery != null and gunnery.has_target():
		_engage(gunnery.target)
		return
	aim_point = fire_control.sight_point(DEFAULT_RANGE)
	gun.aim_at(with_drop(gun.barrel_point(Vector3.ZERO), aim_point, SHELL_SPEED))
	on_target = gun.is_on_target()


func _engage(ship: SurfaceShipEnemy) -> void:
	var origin := gun.barrel_point(Vector3.ZERO)
	var flight := origin.distance_to(ship.global_position) / SHELL_SPEED
	aim_point = ship.global_position + Vector3.UP * SHIP_AIM_HEIGHT + ship.velocity * flight
	gun.aim_at(with_drop(origin, aim_point, SHELL_SPEED))
	on_target = gun.is_on_target()
	if on_target:
		request_fire()


func _on_detonated(position: Vector3, radius: float) -> void:
	fx.explosion(position, radius * BLAST_VISUAL_SCALE)
	turret.apply_camera_shake_impulse(BLAST_SHAKE)
	detonated.emit(position, radius)
