extends Node
class_name SupplyDrops

signal inbound
signal recovered
signal lost

## A crate comes every wave, once the last attackers are in and only this
## many are left, so its parachute tells you the wave is nearly over.
const NEAR_END_HOSTILES: int = 2
const SPAWN_DISTANCE: float = 700.0
const SPAWN_ALTITUDE: float = 260.0
const SPAWN_SPREAD_DEG: float = 30.0
const DESCENT_TIME: float = 18.0

@export var crate_scene: PackedScene
@export var enemies: EnemyManager
@export var waves: WaveOrchestrator
@export var ship: Node3D
@export var landing_point := Vector3(0.0, 10.0, -40.0)
@export var manifest: SupplyManifest
@export var loadout: ShipLoadout
## Fitted at the start of every run: missiles, flares and the radar.
@export var starting_kit: Array[Upgrade] = []

var crate: SupplyCrate

var _due: bool = false


func _ready() -> void:
	loadout.clear()
	for upgrade in starting_kit:
		upgrade.apply_upgrade()
	waves.level_started.connect(_on_level_started)
	waves.level_prepared.connect(_on_level_prepared)
	enemies.enemy_killed.connect(_on_enemy_killed)


func handle_input(event: InputEvent) -> bool:
	return manifest.handle_input(event)


func is_choosing() -> bool:
	return manifest.is_open()


func stop() -> void:
	_due = false
	manifest.dismiss()


func _physics_process(_delta: float) -> void:
	if not _due or not waves.all_spawned() or enemies.hostile_count() > NEAR_END_HOSTILES:
		return
	_due = false
	_drop()


## A wave cleared too fast to catch its crate still gets one as it ends.
func _on_level_prepared(_number: int, _title: String) -> void:
	if _due:
		_due = false
		_drop()


func _on_level_started(_number: int, _title: String) -> void:
	_due = not waves.current_level.blackout


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
