extends Node
class_name WeaponsOrchestrator

const MISSILE_MOUNT := &"vls"

@export var turret: Turret
@export var ballistics: BallisticManager
@export var tracers: ProjectileBatch
@export var missile_launcher: MissileLauncher
@export var salvos: SalvoManager
@export var waves: WaveOrchestrator
@export var enemies: EnemyManager
@export var muzzle_motion: MuzzleMotion
@export var loadout: ShipLoadout

var _enabled: bool = true


func _ready() -> void:
	tracers.sensor = turret.camera
	turret.fired.connect(_on_cannon_fired)
	waves.level_prepared.connect(_on_level_prepared)
	enemies.enemy_killed.connect(_on_enemy_killed)
	loadout.upgrades_changed.connect(_refit)
	loadout.restock_requested.connect(_on_restock_requested)


func set_enabled(value: bool) -> void:
	_enabled = value
	turret.set_enabled(value)
	_refit()


func _refit() -> void:
	var missiles := _missiles_ready()
	missile_launcher.set_enabled(missiles)
	salvos.set_enabled(missiles)
	for weapon in _deck_weapons():
		weapon.set_enabled(_enabled and loadout.is_fitted(weapon.fitting))


func _missiles_ready() -> bool:
	return _enabled and loadout.is_fitted(MISSILE_MOUNT)


func handle_input(event: InputEvent) -> bool:
	if not _enabled or get_tree().paused:
		return false
	if _missiles_ready() and event.is_action_pressed("ciws_salvo"):
		salvos.request_salvo()
		return true
	for weapon in _deck_weapons():
		if weapon.handle_input(event):
			return true
	return false



func _deck_weapons() -> Array[AbstractDeckWeapon]:
	var found: Array[AbstractDeckWeapon] = []
	for child in get_children():
		if child is AbstractDeckWeapon:
			found.append(child)
	return found


func _physics_process(_delta: float) -> void:
	missile_launcher.set_trigger(
		_missiles_ready() and Input.is_action_pressed("ciws_missile")
	)


func _on_cannon_fired(origin: Vector3, velocity: Vector3) -> void:
	if not _enabled or get_tree().paused:
		return
	if muzzle_motion != null:
		velocity += muzzle_motion.carried_velocity()
	var projectile := BulletProjectile.new(tracers, origin, velocity)
	projectile.weapon_source = turret.damage_source
	ballistics.fire(projectile)


func _on_level_prepared(_number: int, _title: String) -> void:
	missile_launcher.refill()


func _on_restock_requested(mount: StringName) -> void:
	for weapon in _deck_weapons():
		if weapon.fitting == mount:
			weapon.restock()


func _on_enemy_killed(enemy: AbstractEnemy, weapon_source: DamageSource) -> void:
	salvos.on_enemy_killed(enemy, weapon_source)
