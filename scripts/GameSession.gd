extends Node
class_name GameSession

static var _singleton : GameSession

enum State { TITLE, STARTING, RUNNING, WON, LOST }

const HIT_IMPULSE: float = 5.0
const HIT_FLASH: float = 0.6
const FLARES_FROM_LEVEL: int = 2
const WRECK_DAMAGE_PER_SIZE: float = 12.0

@onready var turret: Turret = $ViewportContainer/SubViewport/World/Vessel/Turret
@onready var integrity: ShipIntegrity = $ViewportContainer/SubViewport/World/ShipDamage/Integrity
@onready var sinking: ShipSinking = $ViewportContainer/SubViewport/World/ShipDamage/Sinking
@onready var enemies: EnemyManager = $ViewportContainer/SubViewport/World/Enemies
@onready var weapons: WeaponsOrchestrator = $ViewportContainer/SubViewport/World/Weapons
@onready var fx: FXManager = $ViewportContainer/SubViewport/World/FX
@onready var effects: EffectManager = $ViewportContainer/SubViewport/World/Effects
@onready var ballistics: BallisticManager = $ViewportContainer/SubViewport/World/Ballistics
@onready var waves: WaveOrchestrator = $WaveOrchestrator
@onready var thermal: ThermalView = $ViewportContainer
@onready var video: AnalogVideo = $VideoSignal/AnalogVideo
@onready var hud: GameplayHUD = $HUD/HUDRoot
@onready var title_screen: TitleScreen = $HUD/TitleScreen
@onready var score: ScoreKeeper = $Score

var state: State = State.TITLE
var _title_time: float = 0.0


func _ready() -> void:
	if not _singleton:
		_singleton = self
	enemies.enemy_created.connect(_on_enemy_created)
	enemies.enemy_killed.connect(_on_enemy_killed)
	ballistics.entered_water.connect(effects.splash)
	effects.wreck_hit_ship.connect(_on_wreck_hit_ship)
	waves.completed.connect(_on_completed)
	waves.failed.connect(_on_wave_failed)
	title_screen.start_requested.connect(_on_start_requested)
	sinking.sunk.connect(_on_ship_sunk)
	waves.level_prepared.connect(_on_level_prepared)
	hud.hide()
	title_screen.show()
	weapons.set_enabled(false)
	turret.hide_gun = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	if state != State.TITLE and state != State.STARTING:
		return

	_title_time += delta
	turret.rotation.y -= delta * 0.12
	turret.mount.rotation.x = deg_to_rad(
		6.0 + sin(_title_time * 0.4) * 3.0
	)

	if state == State.STARTING:
		if (
			Input.is_action_pressed("ciws_restart")
			or Input.is_action_pressed("ciws_fire")
		):
			return
		_begin()


func _on_start_requested() -> void:
	if state == State.TITLE:
		state = State.STARTING


func _begin() -> void:
	state = State.RUNNING
	title_screen.hide()
	hud.show()
	turret.hide_gun = false
	weapons.set_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	waves.start(enemies)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ciws_palette"):
		video.next_palette()
		get_viewport().set_input_as_handled()
		return
	if state == State.TITLE:
		if title_screen.handle_input(event):
			get_viewport().set_input_as_handled()
		return
	if state == State.STARTING:
		return
	if state != State.RUNNING:
		if event.is_action_pressed("ciws_restart"):
			_restart()
		return
	if event.is_action_pressed("ciws_pause"):
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused:
		return
	if weapons.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		turret.apply_mouse_motion(event.relative)
	elif event.is_action_pressed("ciws_zoom_in"):
		turret.nudge_zoom(0.2)
	elif event.is_action_pressed("ciws_zoom_out"):
		turret.nudge_zoom(-0.2)
	elif event.is_action_pressed("ciws_polarity"):
		thermal.polarity = 1.0 - thermal.polarity


func _on_enemy_created(enemy: AbstractEnemy) -> void:
	enemy.damaged.connect(_on_enemy_damaged)
	enemy.reached_target.connect(_on_target_reached.bind(enemy))
	enemy.countermeasures_released.connect(effects.countermeasures)
	enemy.countermeasures_enabled = waves.level_number >= FLARES_FROM_LEVEL


func _on_level_prepared(number: int, _title: String) -> void:
	if number > 1:
		integrity.repair(integrity.repair_per_wave)


func _on_enemy_damaged(_amount: float, point: Vector3) -> void:
	fx.hit(point)


func _on_enemy_killed(enemy: AbstractEnemy, _weapon_source: DamageSource) -> void:
	fx.explosion(enemy.global_position, 6.0)
	if enemy.blast_size > 0.0:
		effects.spawn(BigExplosionEffect.new(enemy.global_position, enemy.blast_size))
	if enemy.leaves_wreck:
		effects.spawn(ShootDownEffect.new(
			enemy.global_position, enemy.velocity, enemy.hud_radius, enemy.detach_visuals()
		))
	if turret.camera.is_position_in_frustum(enemy.global_position):
		thermal.heat_burst()


func _on_target_reached(damage: float, enemy: AbstractEnemy) -> void:
	if state != State.RUNNING:
		return
	integrity.take_hit(damage, enemy.global_position)
	if enemy.blast_size > 0.0:
		effects.spawn(BigExplosionEffect.new(_on_ship(enemy.global_position), enemy.blast_size))
	turret.apply_camera_shake_impulse(HIT_IMPULSE)
	thermal.heat_burst(HIT_FLASH)


func _on_ship(above: Vector3) -> Vector3:
	var deck := effects.deck_height_at(above)
	return Vector3(above.x, effects.sea_level() if is_nan(deck) else deck, above.z)


func _on_wreck_hit_ship(position: Vector3, size: float) -> void:
	if state == State.RUNNING:
		integrity.take_hit(WRECK_DAMAGE_PER_SIZE * size, position)


func _on_ship_sunk() -> void:
	_finish(State.LOST, "SHIP LOST")


func _on_completed() -> void:
	_finish(State.WON, "MISSION COMPLETE")


func _on_wave_failed(reason: String) -> void:
	push_error(reason)
	_finish(State.LOST, "LEVEL UNAVAILABLE")


func _set_paused(paused: bool) -> void:
	weapons.set_enabled(not paused)
	get_tree().paused = paused
	Input.mouse_mode = (
		Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	)
	hud.message = "PAUSED - ESC TO RESUME" if paused else ""


func _finish(result: State, message: String) -> void:
	if state != State.RUNNING:
		return
	state = result
	waves.stop()
	score.record_final()
	weapons.set_enabled(false)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.message = message + " - CLICK OR ENTER TO RESTART"


func _restart() -> void:
	get_tree().paused = false
	var error := get_tree().reload_current_scene()
	if error != OK:
		push_error("Could not reload the gameplay scene.")

static func is_state(state2: State) -> bool:
	return _singleton.state == state2