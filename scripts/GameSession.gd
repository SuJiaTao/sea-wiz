extends Node
class_name GameSession

enum State { TITLE, STARTING, RUNNING, WON, LOST }

const HULL_MAX: float = 100.0

@onready var turret: Turret = $ViewportContainer/SubViewport/World/Turret
@onready var enemies: EnemyManager = $ViewportContainer/SubViewport/World/Enemies
@onready var weapons: WeaponsOrchestrator = $ViewportContainer/SubViewport/World/Weapons
@onready var fx: FXManager = $ViewportContainer/SubViewport/World/FX
@onready var waves: WaveOrchestrator = $WaveOrchestrator
@onready var thermal: ThermalView = $ViewportContainer
@onready var video: AnalogVideo = $VideoSignal/AnalogVideo
@onready var hud: GameplayHUD = $HUD/HUDRoot
@onready var title_screen: TitleScreen = $HUD/TitleScreen

var state: State = State.TITLE
var hull: float = HULL_MAX
var _title_time: float = 0.0


func _ready() -> void:
	enemies.enemy_created.connect(_on_enemy_created)
	enemies.enemy_killed.connect(_on_enemy_killed)
	waves.completed.connect(_on_completed)
	waves.failed.connect(_on_wave_failed)
	title_screen.start_requested.connect(_on_start_requested)
	hud.set_health(hull, HULL_MAX)
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
	enemy.reached_target.connect(_on_target_reached)


func _on_enemy_damaged(_amount: float, point: Vector3) -> void:
	fx.hit(point)


func _on_enemy_killed(enemy: AbstractEnemy, _weapon_source: DamageSource) -> void:
	fx.explosion(enemy.global_position, 6.0)


func _on_target_reached(damage: float) -> void:
	if state != State.RUNNING:
		return
	hull = maxf(hull - maxf(damage, 0.0), 0.0)
	hud.set_health(hull, HULL_MAX)
	turret.add_impulse(5.0)
	if hull <= 0.0:
		_finish(State.LOST, "DEFENCE LOST")


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
	weapons.set_enabled(false)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.message = message + " - CLICK OR ENTER TO RESTART"


func _restart() -> void:
	get_tree().paused = false
	var error := get_tree().reload_current_scene()
	if error != OK:
		push_error("Could not reload the gameplay scene.")
