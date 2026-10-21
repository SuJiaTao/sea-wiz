extends Node
class_name WeaponsOrchestrator

@export var turret: Turret
@export var ballistics: BallisticManager
@export var tracers: ProjectileBatch
@export var missile_launcher: MissileLauncher
@export var salvos: SalvoManager
@export var waves: WaveOrchestrator
@export var enemies: EnemyManager

var _enabled: bool = true


func _ready() -> void:
	tracers.sensor = turret.camera
	turret.fired.connect(_on_cannon_fired)
	waves.level_prepared.connect(_on_level_prepared)
	enemies.enemy_killed.connect(_on_enemy_killed)


func set_enabled(value: bool) -> void:
	_enabled = value
	turret.set_enabled(value)
	missile_launcher.set_enabled(value)
	salvos.set_enabled(value)


func handle_input(event: InputEvent) -> bool:
	if not _enabled or get_tree().paused:
		return false
	if event.is_action_pressed("ciws_salvo"):
		salvos.request_salvo()
		return true
	return false


func _physics_process(_delta: float) -> void:
	missile_launcher.set_trigger(
		_enabled and Input.is_action_pressed("ciws_missile")
	)


func _on_cannon_fired(origin: Vector3, velocity: Vector3) -> void:
	if not _enabled or get_tree().paused:
		return
	var projectile := BulletProjectile.new(tracers, origin, velocity)
	projectile.weapon_source = turret.damage_source
	ballistics.fire(projectile)


func _on_level_prepared(_number: int, _title: String) -> void:
	missile_launcher.refill()


func _on_enemy_killed(enemy: AbstractEnemy, weapon_source: DamageSource) -> void:
	salvos.on_enemy_killed(enemy, weapon_source)
