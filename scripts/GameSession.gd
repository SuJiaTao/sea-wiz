extends Node
class_name GameSession

static var _singleton : GameSession

enum State { TITLE, STARTING, RUNNING, WON, LOST }

const HIT_IMPULSE: float = 5.0
const HIT_FLASH: float = 0.6
const WRECK_DAMAGE_PER_SIZE: float = 12.0
const HUD_FIRST_TIME: float = 0.9
const NIGHT_VISION_FADE: float = 3.0

@onready var turret: Turret = $ViewportContainer/SubViewport/World/Vessel/Turret
@onready var integrity: ShipIntegrity = $ViewportContainer/SubViewport/World/ShipDamage/Integrity
@onready var loss: ShipLoss = $ViewportContainer/SubViewport/World/ShipDamage/Loss
@onready var enemies: EnemyManager = $ViewportContainer/SubViewport/World/Enemies
@onready var weapons: WeaponsOrchestrator = $ViewportContainer/SubViewport/World/Weapons
@onready var fx: FXManager = $ViewportContainer/SubViewport/World/FX
@onready var effects: EffectManager = $ViewportContainer/SubViewport/World/Effects
@onready var ballistics: BallisticManager = $ViewportContainer/SubViewport/World/Ballistics
@onready var waves: WaveOrchestrator = $WaveOrchestrator
@onready var thermal: ThermalView = $ViewportContainer
@onready var video: AnalogVideo = $VideoSignal/AnalogVideo
@onready var hud: GameplayHUD = $HUD/HUDRoot
@onready var title_screen: TitleScreen = $TitleScreen
@onready var score: ScoreKeeper = $Score
@onready var supplies: SupplyDrops = $SupplyDrops
@onready var doctrine: EnemyDoctrine = $EnemyDoctrine
@onready var wake_fade: ColorRect = $WakeFade/Black
@onready var pause_menu: PauseMenu = $HUD/PauseMenu

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
	title_screen.dusk_finished.connect(_wake_up)
	pause_menu.resume_requested.connect(_set_paused.bind(false))
	pause_menu.restart_requested.connect(_restart)
	pause_menu.quit_requested.connect(quit_game)
	loss.lost.connect(_on_ship_lost)
	waves.level_prepared.connect(_on_level_prepared)
	supplies.loadout.repair_requested.connect(integrity.repair)
	supplies.recovered.connect(weapons.restock_missiles)
	waves.level_started.connect(doctrine.reassess.unbind(2))
	hud.hide()
	title_screen.show()
	weapons.set_enabled(false)
	turret.hide_gun = true
	if CursorManager.is_mouse_captured():
		CursorManager.free_mouse()
	DevConsole.register_command("quit", quit_game.unbind(1))


func _process(delta: float) -> void:
	if state != State.TITLE:
		return
	_title_time += delta
	turret.rotation.y -= delta * 0.12
	turret.mount.rotation.x = deg_to_rad(
		6.0 + sin(_title_time * 0.4) * 3.0
	)


func _on_start_requested() -> void:
	if state == State.TITLE:
		state = State.STARTING
		title_screen.play_dusk()


## After the sunset: the screen is black, the green HUD lights first, then the
## night vision picture slowly comes up and the fight begins.
func _wake_up() -> void:
	title_screen.hide()
	turret.rotation.y = 0.0
	turret.mount.rotation.x = 0.0
	wake_fade.color = Color.BLACK
	hud.show()
	var tween := create_tween()
	tween.tween_interval(HUD_FIRST_TIME)
	tween.tween_property(wake_fade, "color:a", 0.0, NIGHT_VISION_FADE)
	tween.tween_callback(_begin)


func _begin() -> void:
	state = State.RUNNING
	title_screen.hide()
	wake_fade.color.a = 0.0
	hud.show()
	turret.hide_gun = false
	weapons.set_enabled(true)
	CursorManager.capture_mouse()
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
		if pause_menu.handle_input(event):
			get_viewport().set_input_as_handled()
		return
	if supplies.handle_input(event):
		get_viewport().set_input_as_handled()
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


func _on_ship_lost() -> void:
	_finish(State.LOST, "SIGNAL LOST")


func _on_completed() -> void:
	_finish(State.WON, "MISSION COMPLETE")


func _on_wave_failed(reason: String) -> void:
	push_error(reason)
	_finish(State.LOST, "LEVEL UNAVAILABLE")


func _set_paused(paused: bool) -> void:
	weapons.set_enabled(not paused)
	get_tree().paused = paused
	CursorManager.free_mouse(paused)
	if paused:
		pause_menu.open()
	else:
		pause_menu.close()


func _finish(result: State, message: String) -> void:
	if state != State.RUNNING:
		return
	state = result
	waves.stop()
	supplies.stop()
	score.record_final()
	weapons.set_enabled(false)
	get_tree().paused = true
	CursorManager.free_mouse()
	video.set_blackout(0.0)
	hud.show()
	hud.message = message + " - CLICK OR ENTER TO RESTART"


func _restart() -> void:
	get_tree().paused = false
	var error := get_tree().reload_current_scene()
	if error != OK:
		push_error("Could not reload the gameplay scene.")

static func is_state(state2: State) -> bool:
	return _singleton.state == state2


func quit_game() -> void:
	DevConsole.print_to_console("quitting...")
	# DevConsole.dump_history()
	get_tree().quit.call_deferred()