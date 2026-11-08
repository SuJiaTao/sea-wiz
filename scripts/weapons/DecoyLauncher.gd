extends Node
class_name DecoyLauncher
## Fires a chaff rocket to each beam. The clouds bloom off the ship and
## pull incoming missiles away from it.

signal launched()
signal bloomed(point: Vector3)

const COOLDOWN: float = 18.0
const BLOOM_DELAY: float = 0.9
const CLOUD_TIME: float = 7.0
const CLOUD_OFFSET := Vector3(130.0, 40.0, 0.0)
const LURE_RANGE: float = 2600.0
const LURE_CHANCE: float = 0.8
const LAUNCH_PUFFS: int = 14
const LAUNCH_SPEED := Vector2(2.0, 7.0)
const CLOUD_PUFFS: int = 70
const CLOUD_SPEED := Vector2(4.0, 16.0)
const CLOUD_SIZE: float = 2.5
const BLOOM_SPARKS: int = 30
const BLOOM_FLASH: float = 6.0

@export var enemies: EnemyManager
@export var smoke: ParticleBatch
@export var fx: FXManager
@export var tubes: Node3D

var cooldown_left: float = 0.0

var _enabled: bool = true
var _clouds: Array[Vector3] = []
var _cloud_left: float = 0.0
var _bloom_left: float = 0.0
var _judged: Dictionary[AbstractEnemy, bool] = {}


func _ready() -> void:
	add_to_group(WeaponsOrchestrator.DECK_WEAPONS)


func set_enabled(value: bool) -> void:
	_enabled = value


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ciws_decoy"):
		request_launch()
		return true
	return false


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
	if _cloud_left <= 0.0:
		return
	_cloud_left -= delta
	for enemy in enemies.live_enemies():
		if enemy.contact_kind != AbstractEnemy.ContactKind.MISSILE:
			continue
		if _judged.has(enemy):
			continue
		var distance := enemy.global_position.distance_to(tubes.global_position)
		if distance > LURE_RANGE:
			continue
		_judged[enemy] = randf() < LURE_CHANCE and enemy.lure(_nearest_cloud(enemy))


func _bloom() -> void:
	_clouds.clear()
	_judged.clear()
	_cloud_left = CLOUD_TIME
	for side in [-1.0, 1.0]:
		var offset := CLOUD_OFFSET * Vector3(side, 1.0, 1.0)
		var point := tubes.global_position + tubes.global_basis * offset
		_clouds.append(point)
		smoke.burst(point, CLOUD_PUFFS, CLOUD_SPEED, CLOUD_SIZE)
		fx.spark_burst(point, BLOOM_SPARKS)
		fx.explosion(point, BLOOM_FLASH)
		bloomed.emit(point)


func _nearest_cloud(enemy: AbstractEnemy) -> Vector3:
	var best := _clouds[0]
	for cloud in _clouds:
		if enemy.global_position.distance_to(cloud) < enemy.global_position.distance_to(best):
			best = cloud
	return best
