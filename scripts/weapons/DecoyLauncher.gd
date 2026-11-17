extends AbstractDeckWeapon
class_name DecoyLauncher

signal launched()
signal bloomed(point: Vector3)

const COOLDOWN: float = 18.0
const BLOOM_DELAY: float = 0.9
const CLOUD_TIME: float = 7.0
const CLOUD_OFFSET := Vector3(130.0, 40.0, 0.0)
const LAUNCH_PUFFS: int = 14
const LAUNCH_SPEED := Vector2(2.0, 7.0)
const CLOUD_PUFFS: int = 70
const CLOUD_SPEED := Vector2(4.0, 16.0)
const CLOUD_SIZE: float = 2.5
const BLOOM_SPARKS: int = 30
const BLOOM_FLASH: float = 6.0
const BEAM_SIDES: Array[float] = [-1.0, 1.0]
const CHAFF_LURE_CHANCE: float = 0.8
const IR_MOUNT := &"ir_decoys"
const IR_LURE_CHANCE: float = 0.95
const IR_CLOUD_TIME: float = 10.0
const IR_FLARES_PER_CLOUD: int = 3
const IR_SPREAD_SPEED := Vector2(6.0, 14.0)
const IR_PARACHUTE_DRAG: float = 3.3
const IR_BURN_TIME := Vector2(8.0, 11.0)

@export var enemies: EnemyManager
@export var smoke: ParticleBatch
@export var fx: FXManager
@export var tubes: Node3D
@export var effects: EffectManager
@export var loadout: ShipLoadout

var cooldown_left: float = 0.0

var _bloom_left: float = 0.0
var _screen: ChaffScreen


func _trigger() -> void:
	request_launch()


func restock() -> void:
	cooldown_left = 0.0


func request_launch() -> bool:
	if not _enabled or cooldown_left > 0.0:
		return false
	cooldown_left = COOLDOWN
	_bloom_left = BLOOM_DELAY
	for tube in tubes.get_children():
		smoke.burst((tube as Node3D).global_position, LAUNCH_PUFFS, LAUNCH_SPEED)
	launched.emit()
	return true


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	if _bloom_left > 0.0:
		_bloom_left -= delta
		if _bloom_left <= 0.0:
			_bloom()
	if _screen == null or not _screen.is_active():
		return
	_screen.age(delta)
	_screen.seduce(enemies.live_enemies(), tubes.global_position)


func _bloom() -> void:
	var clouds: Array[Vector3] = []
	for side in BEAM_SIDES:
		var offset := CLOUD_OFFSET * Vector3(side, 1.0, 1.0)
		var point := tubes.global_position + tubes.global_basis * offset
		clouds.append(point)
		smoke.burst(point, CLOUD_PUFFS, CLOUD_SPEED, CLOUD_SIZE)
		fx.spark_burst(point, BLOOM_SPARKS)
		fx.explosion(point, BLOOM_FLASH)
		bloomed.emit(point)
	if loadout != null and loadout.is_fitted(IR_MOUNT):
		_release_flares(clouds)
		_screen = ChaffScreen.new(clouds, IR_CLOUD_TIME, IR_LURE_CHANCE)
	else:
		_screen = ChaffScreen.new(clouds, CLOUD_TIME, CHAFF_LURE_CHANCE)


func _release_flares(clouds: Array[Vector3]) -> void:
	var flares: Array[DecoyFlare] = []
	for point in clouds:
		for index in IR_FLARES_PER_CLOUD:
			var spread := ParticleBatch.random_direction() * randf_range(IR_SPREAD_SPEED.x, IR_SPREAD_SPEED.y)
			var burn := randf_range(IR_BURN_TIME.x, IR_BURN_TIME.y)
			flares.append(DecoyFlare.new(point, spread, IR_PARACHUTE_DRAG, burn))
	effects.countermeasures(flares)

