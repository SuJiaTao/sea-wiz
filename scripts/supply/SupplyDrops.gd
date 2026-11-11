extends Node
class_name SupplyDrops

signal inbound
signal recovered
signal lost

const DROP_CHANCE: float = 0.5
const MAX_WAVES_WITHOUT_DROP: int = 2
const DROP_DELAY := Vector2(4.0, 12.0)
const SPAWN_DISTANCE: float = 700.0
const SPAWN_ALTITUDE: float = 260.0
const SPAWN_SPREAD_DEG: float = 30.0
const DESCENT_TIME: float = 40.0
const NO_DROP: float = -1.0

@export var crate_scene: PackedScene
@export var enemies: EnemyManager
@export var waves: WaveOrchestrator
@export var ship: Node3D
@export var landing_point := Vector3(0.0, 10.0, -40.0)
@export var manifest: SupplyManifest
@export var loadout: ShipLoadout

var crate: SupplyCrate

var _waves_without_drop: int = 0
var _drop_in: float = NO_DROP


func _ready() -> void:
	loadout.clear()
	waves.level_started.connect(_on_level_started)
	enemies.enemy_killed.connect(_on_enemy_killed)


func handle_input(event: InputEvent) -> bool:
	return manifest.handle_input(event)


func is_choosing() -> bool:
	return manifest.is_open()


func stop() -> void:
	_drop_in = NO_DROP
	manifest.dismiss()


func _physics_process(delta: float) -> void:
	if _drop_in == NO_DROP:
		return
	_drop_in = maxf(_drop_in - delta, 0.0)
	if _drop_in == 0.0:
		_drop_in = NO_DROP
		_drop()


func _on_level_started(_number: int, _title: String) -> void:
	_waves_without_drop += 1
	if _waves_without_drop >= MAX_WAVES_WITHOUT_DROP or randf() < DROP_CHANCE:
		_waves_without_drop = 0
		_drop_in = randf_range(DROP_DELAY.x, DROP_DELAY.y)


func _drop() -> void:
	if is_instance_valid(crate):
		return
	var bearing := deg_to_rad(randf_range(-SPAWN_SPREAD_DEG, SPAWN_SPREAD_DEG))
	var landing := ship.global_transform * landing_point
	var approach := Vector3.FORWARD.rotated(Vector3.UP, bearing) * SPAWN_DISTANCE
	var start := landing + approach + Vector3.UP * SPAWN_ALTITUDE
	crate = crate_scene.instantiate() as SupplyCrate
	crate.landing = landing
	crate.descent_time = DESCENT_TIME
	crate.recovered.connect(_on_recovered.bind(crate))
	if enemies.create(crate, Transform3D(Basis.IDENTITY, start)):
		inbound.emit()


func _on_recovered(delivered: SupplyCrate) -> void:
	if delivered != crate:
		return
	crate = null
	recovered.emit()
	manifest.open()


func _on_enemy_killed(enemy: AbstractEnemy, _weapon_source: DamageSource) -> void:
	if enemy == crate:
		crate = null
		lost.emit()
