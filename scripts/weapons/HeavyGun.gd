extends AbstractDeckWeapon
class_name HeavyGun

# The single-barrel gun near the bow. It follows the CIWS sight and fires one
# heavy round per shot: slower than the CIWS, but it hits far harder.

signal fired(origin: Vector3)

const ROUND_SPEED: float = 950.0
const ROUND_DAMAGE: float = 520.0
const RELOAD_TIME: float = 0.9
const TRACER_LENGTH: float = 18.0
const DEFAULT_RANGE: float = 1500.0
const SHIP_AIM_HEIGHT: float = 6.0
const MUZZLE := Vector3(0.0, 0.0, -8.15)
const MUZZLE_SHAKE: float = 1.4

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


func _trigger() -> void:
	request_fire()


func readiness() -> float:
	return 1.0 - reload_left / RELOAD_TIME


func fall_of_shot() -> Vector3:
	var origin := gun.barrel_point(Vector3.ZERO)
	return origin + gun.muzzle_direction() * origin.distance_to(aim_point)


func request_fire() -> bool:
	if not _enabled or reload_left > 0.0:
		return false
	reload_left = RELOAD_TIME
	var origin := gun.barrel_point(MUZZLE)
	var heavy := BulletProjectile.new(tracers, origin, gun.muzzle_direction() * ROUND_SPEED)
	heavy.damage = ROUND_DAMAGE
	heavy.tracer_length = TRACER_LENGTH
	heavy.weapon_source = damage_source
	ballistics.fire(heavy)
	gun.fire()
	fx.hit(origin)
	turret.apply_camera_shake_impulse(MUZZLE_SHAKE)
	fired.emit(origin)
	return true


func _physics_process(delta: float) -> void:
	reload_left = maxf(reload_left - delta, 0.0)
	if not _enabled:
		gun.park()
		on_target = false
		return
	if gunnery != null and gunnery.has_target():
		_engage(gunnery.target)
		return
	aim_point = fire_control.sight_point(DEFAULT_RANGE)
	gun.aim_at(with_drop(gun.barrel_point(Vector3.ZERO), aim_point, ROUND_SPEED))
	on_target = gun.is_on_target()


func _engage(ship: SurfaceShipEnemy) -> void:
	var origin := gun.barrel_point(Vector3.ZERO)
	var flight := origin.distance_to(ship.global_position) / ROUND_SPEED
	aim_point = ship.global_position + Vector3.UP * SHIP_AIM_HEIGHT + ship.velocity * flight
	gun.aim_at(with_drop(origin, aim_point, ROUND_SPEED))
	on_target = gun.is_on_target()
	if on_target:
		request_fire()
