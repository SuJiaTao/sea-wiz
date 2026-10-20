extends Node
class_name Game
## Top-level controller: builds the world, runs the wave director, owns the
## score, and drives the thermal post-process parameters.

enum State { TITLE, BRIEF, RUNNING, OVER }

const HULL_MAX := 100.0
const INTERMISSION := 7.0
const SAVE_PATH := "user://ciws_profile.json"

## The first levels are authored so a new player (or anyone watching) sees
## the good stuff early. Past these, the budget-driven director takes over.
const LEVEL_NAMES := ["FIRST CONTACT", "SATURATION", "MOTHERSHIP", "ORBITAL"]

# Wave director tuning.
const BASE_BUDGET := 4.0
const BUDGET_PER_WAVE := 2.2
const SPAWN_GAP := Vector2(0.6, 2.6)

@onready var container: SubViewportContainer = $ViewportContainer
@onready var viewport: SubViewport = $ViewportContainer/SubViewport
@onready var world: Node3D = $ViewportContainer/SubViewport/World
@onready var world_env: WorldEnvironment = $ViewportContainer/SubViewport/World/WorldEnvironment
@onready var turret: Turret = $ViewportContainer/SubViewport/World/Turret
@onready var ballistics: BallisticManager = $ViewportContainer/SubViewport/World/Ballistics
@onready var enemies_root: Node3D = $ViewportContainer/SubViewport/World/Enemies
@onready var hud: Control = $HUD/HUDRoot

var fx: FXManager
var bullet_renderer: ProjectileBatch
var missile_renderer: ProjectileBatch
var missile_smoke: MissileSmokeRenderer
var thermal: ShaderMaterial

var state: int = State.TITLE
var wave: int = 0
var hull: float = HULL_MAX
var score: int = 0
var kills: int = 0
var leaks: int = 0
var hits: int = 0
var misses: int = 0
var missiles_fired: int = 0
var missile_kills: int = 0
var best_wave: int = 0
var best_score: int = 0

var polarity: float = 0.0
var brief_timer: float = 3.0
var wave_label: String = ""
var salvo_label: String = ""
var salvo_label_timer: float = 0.0

# Presentation state read by the HUD.
var banner_title: String = ""
var banner_sub: String = ""
var banner_timer: float = 0.0
var splash_text: String = ""
var splash_timer: float = 0.0
var hit_flash: float = 0.0
var kill_flash: float = 0.0
var title_time: float = 0.0
## Sensor whiteout, 0..1. Spikes when a warp ship drops in or a capital ship
## blows, and drains away over about half a second.
var sensor_flash: float = 0.0

var _queue: Array = []          # [{type_id, t}] pending spawns for this wave
var _queue_time: float = 0.0
var _wave_active: bool = false
var _paused: bool = false
var _pixel_scale: int = 4
## Attract / test mode: the mount tracks and engages on its own.
## Enable with the environment variable CIWS_DEMO=1.
var _demo: bool = false
## Staggered blasts down a dying capital ship: [{pos, size, t}].
var _pending_blasts: Array = []
var _banner_queue: Array = []
var _blast_clock: float = 0.0
var _warp_sound: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()

	_setup_viewport()
	_setup_environment()
	_build_static_world()

	fx = FXManager.new()
	fx.name = "FX"
	world.add_child(fx)

	_setup_ballistics()

	_warp_sound = AudioStreamPlayer.new()
	_warp_sound.name = "WarpSound"
	if ResourceLoader.exists("res://audio/warp_arrival.wav"):
		_warp_sound.stream = load("res://audio/warp_arrival.wav")
	_warp_sound.volume_db = 0.0
	add_child(_warp_sound)

	_load_profile()

	_demo = OS.get_environment("CIWS_DEMO") == "1" or OS.has_feature("ciws_demo")
	# CIWS_START_WAVE=12 drops you straight into the capital-ship waves.
	var sw := OS.get_environment("CIWS_START_WAVE")
	if sw.is_valid_int():
		wave = maxi(int(sw) - 1, 0)

	if _demo:
		_begin()
	else:
		# Title screen: the mount idles and slowly sweeps until someone clicks.
		state = State.TITLE
		turret.set_enabled(false)
		turret.hide_gun = true
		_capture_mouse(false)


## Leaves the title screen.
func _begin() -> void:
	state = State.BRIEF
	brief_timer = 3.0
	wave_label = "SYSTEM READY"
	turret.set_enabled(true)
	turret.hide_gun = false
	_capture_mouse(not _demo)


# ---------------------------------------------------------------------------
# World construction
# ---------------------------------------------------------------------------

func _setup_viewport() -> void:
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.offset_left = 0
	container.offset_top = 0
	container.offset_right = 0
	container.offset_bottom = 0
	container.stretch = true
	container.stretch_shrink = _pixel_scale
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = false
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.transparent_bg = false
	viewport.positional_shadow_atlas_size = 0

	var sh: Shader = load("res://shaders/thermal.gdshader")
	thermal = ShaderMaterial.new()
	thermal.shader = sh
	# CIWS_RAW=1 shows the un-processed 3D render, which is how you debug what
	# the sensor is actually looking at.
	if OS.get_environment("CIWS_RAW") != "1":
		container.material = thermal
	_update_sensor_size()
	get_tree().get_root().size_changed.connect(_update_sensor_size)

	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.set("game", self)


func _update_sensor_size() -> void:
	if thermal == null:
		return
	var s := Vector2(get_viewport().get_visible_rect().size) / float(_pixel_scale)
	thermal.set_shader_parameter("sensor_size", s.max(Vector2(64, 36)))


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_white = 1.0

	# Only genuinely over-bright surfaces (exhaust plumes, tracers, blasts) are
	# allowed to bloom. glow_bloom must stay at 0: it lifts EVERY pixel before
	# the threshold test and washes the black sky out to grey.
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_strength = 0.8
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 2.0

	# Atmospheric attenuation: distant contacts dim out the way they do on a
	# real IR sensor, which is also what gives the sky its horizon gradient.
	env.fog_enabled = true
	env.fog_light_color = Color(0, 0, 0, 1)
	env.fog_light_energy = 0.0
	env.fog_density = 0.00025
	env.fog_aerial_perspective = 0.0

	world_env.environment = env


func _build_static_world() -> void:
	# Sea.
	var plane := PlaneMesh.new()
	plane.size = Vector2(14000, 14000)
	plane.subdivide_width = 24
	plane.subdivide_depth = 24
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = plane
	var sea_mat := ShaderMaterial.new()
	sea_mat.shader = load("res://shaders/sea.gdshader")
	sea.material_override = sea_mat
	sea.position = Vector3(0, -1.6, 0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(sea)

	# The deck you are bolted to.
	var deck := MeshFactory.build_deck()
	deck.name = "Deck"
	world.add_child(deck)


# ---------------------------------------------------------------------------
# Wave director
# ---------------------------------------------------------------------------

## Authored opening levels. Times are seconds from the start of the wave.
func _authored_wave(w: int) -> Array:
	match w:
		1:
			return [
				{"type": "drone", "t": 0.0}, {"type": "drone", "t": 1.5},
				{"type": "drone", "t": 3.0}, {"type": "drone", "t": 5.0},
				{"type": "drone", "t": 7.0}, {"type": "drone", "t": 9.0},
				{"type": "jet", "t": 12.0}, {"type": "jet", "t": 15.0},
			]
		2:
			return [
				{"type": "drone", "t": 0.0}, {"type": "drone", "t": 1.0},
				{"type": "drone", "t": 2.0}, {"type": "helo", "t": 3.0},
				{"type": "jet", "t": 5.0}, {"type": "missile", "t": 7.0},
				{"type": "jet", "t": 9.0}, {"type": "missile", "t": 11.0},
				{"type": "helo", "t": 12.0}, {"type": "heavy_jet", "t": 14.0},
				{"type": "missile", "t": 17.0}, {"type": "missile", "t": 18.0},
			]
		3:
			# The carrier arrives first and does most of the spawning itself.
			return [
				{"type": "mothership", "t": 0.0},
				{"type": "jet", "t": 6.0}, {"type": "jet", "t": 9.0},
			]
		4:
			# A dreadnought drops out of warp overhead and empties its hangars
			# on you. It waits for the level banner so the warning reads first.
			return [
				{"type": "dreadnought", "t": 3.4},
				{"type": "jet", "t": 9.0}, {"type": "jet", "t": 11.0},
				{"type": "helo", "t": 20.0}, {"type": "missile", "t": 26.0},
			]
	return []


func level_name(w: int) -> String:
	if w >= 1 and w <= LEVEL_NAMES.size():
		return String(LEVEL_NAMES[w - 1])
	return "WAVE %02d" % w


func _build_wave(w: int) -> Array:
	var authored := _authored_wave(w)
	if not authored.is_empty():
		return authored
	var budget := BASE_BUDGET + BUDGET_PER_WAVE * float(w)
	var pool := EnemyDB.ids_available_at(w)
	var out: Array = []
	var t := 0.0
	var guard := 0
	var gap_scale: float = clampf(1.0 - float(w) * 0.03, 0.45, 1.0)

	while budget > 0.5 and guard < 60:
		guard += 1
		var affordable: Array = []
		for id in pool:
			if float(EnemyDB.get_type(id)["cost"]) <= budget + 0.4:
				affordable.append(id)
		if affordable.is_empty():
			break
		# Bias toward the biggest thing the budget still allows, so late waves
		# are not just a swarm of drones.
		affordable.sort_custom(func(a, b):
			return float(EnemyDB.get_type(a)["cost"]) > float(EnemyDB.get_type(b)["cost"]))
		var idx: int = 0
		if affordable.size() > 1:
			idx = mini(int(absf(randfn(0.0, 1.35))), affordable.size() - 1)
		var pick: String = affordable[idx]
		budget -= float(EnemyDB.get_type(pick)["cost"])
		out.append({"type": pick, "t": t})
		t += randf_range(SPAWN_GAP.x, SPAWN_GAP.y) * gap_scale

	if out.is_empty():
		out.append({"type": "drone", "t": 0.0})
	return out


func _start_wave(w: int) -> void:
	wave = w
	_queue = _build_wave(w)
	_queue_time = 0.0
	_wave_active = true
	wave_label = "WAVE %02d - %d CONTACTS INBOUND" % [w, _queue.size()]
	turret.refill_missiles()
	_show_banner("LEVEL %02d" % w, level_name(w), 3.2)
	state = State.RUNNING


## Banners queue rather than stomp each other, so "LEVEL 03" is read before
## the boss warning that follows it.
func _show_banner(title: String, sub: String, secs: float) -> void:
	if banner_timer > 0.5:
		_banner_queue.append([title, sub, secs])
		return
	banner_title = title
	banner_sub = sub
	banner_timer = secs


func flash_message(text: String, secs: float) -> void:
	salvo_label = text
	salvo_label_timer = secs


## Compass bearing from the mount to a world position, in degrees.
func bearing_to(p: Vector3) -> int:
	return int(round(fposmod(rad_to_deg(atan2(p.x, -p.z)), 360.0)))


func _spawn(type_id: String, at: Vector3 = Vector3.INF, heading: Vector3 = Vector3.ZERO) -> Enemy:
	var d := EnemyDB.get_type(type_id)
	var pos := at
	if pos == Vector3.INF:
		var a := randf() * TAU
		var dist := randf_range(float(d["dist"][0]), float(d["dist"][1]))
		var alt := randf_range(float(d["alt"][0]), float(d["alt"][1]))
		pos = Vector3(cos(a) * dist, alt, sin(a) * dist)

	var e := Enemy.new()
	enemies_root.add_child(e)
	e.add_to_group("enemy")
	e.setup(type_id, pos)
	if heading != Vector3.ZERO:
		e.velocity = heading.normalized() * e.speed
	e.died.connect(_on_enemy_died)
	e.leaked.connect(_on_enemy_leaked)
	e.launch_requested.connect(_on_launch_requested)
	e.bay_opened.connect(_on_bay_opened)
	e.warp_started.connect(_on_warp_started)
	e.warp_arrived.connect(_on_warp_arrived)
	if e.warping:
		_show_banner("WARNING", "GRAVITY WAVE  BEARING %03d" % bearing_to(pos), 3.0)
		if _warp_sound.stream != null:
			_warp_sound.play()
	elif e.is_boss and at == Vector3.INF:
		_show_banner("WARNING", "%s INBOUND  BEARING %03d" % [e.display, bearing_to(pos)], 4.0)
	return e


func _on_warp_started(_enemy: Enemy) -> void:
	sensor_flash = 1.0
	turret.add_impulse(6.0)


func _on_warp_arrived(enemy: Enemy) -> void:
	turret.add_impulse(2.5)
	_show_banner("WARNING", "%s  BEARING %03d" % [enemy.display, bearing_to(enemy.global_position)], 4.0)


func live_enemies() -> Array:
	var out: Array = []
	for c in enemies_root.get_children():
		var e := c as Enemy
		if e != null and e.alive:
			out.append(e)
	return out


# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

func _setup_ballistics() -> void:
	bullet_renderer = ProjectileBatch.new()
	bullet_renderer.name = "BulletRenderer"
	bullet_renderer.batch_mesh = BulletProjectile.make_mesh()
	bullet_renderer.capacity = 900
	bullet_renderer.sensor = turret.camera
	bullet_renderer.near_cull = 10.0
	bullet_renderer.zoom_near_cull = 70.0
	world.add_child(bullet_renderer)

	missile_renderer = ProjectileBatch.new()
	missile_renderer.name = "MissileRenderer"
	missile_renderer.batch_mesh = MeshFactory.build_missile_mesh()
	missile_renderer.capacity = 32
	world.add_child(missile_renderer)

	missile_smoke = MissileSmokeRenderer.new()
	missile_smoke.name = "MissileSmoke"
	missile_smoke.sensor = turret.camera
	world.add_child(missile_smoke)

	turret.fired.connect(_on_turret_fired)
	turret.missile_launched.connect(_on_missile_launched)


func _on_turret_fired(origin: Vector3, velocity: Vector3) -> void:
	var projectile := BulletProjectile.new(bullet_renderer, origin, velocity)
	projectile.hit_enemy.connect(_on_bullet_hit)
	projectile.round_expired.connect(_on_round_expired)
	ballistics.fire(projectile)


func _on_round_expired() -> void:
	misses += 1


func _on_bullet_hit(enemy: Enemy, point: Vector3, killed: bool) -> void:
	hits += 1
	hit_flash = 0.08
	fx.hit(point)
	if killed:
		# Only gun kills feed the combo, so the salvo stays something you earn
		# with the cannon rather than a second trigger.
		turret.add_combo_kill()
		_kill(enemy, point)


func _on_missile_launched(origin: Vector3, direction: Vector3, target: Enemy) -> void:
	var projectile := GuidedMissileProjectile.new(
		missile_renderer, missile_smoke, get_tree(), origin, direction, target
	)
	projectile.hit_enemy.connect(_on_missile_hit)
	projectile.detonated.connect(_on_missile_detonated)
	if not ballistics.fire(projectile):
		return
	missiles_fired += 1
	if not turret.salvo_active():
		flash_message("MISSILE AWAY", 1.1)


func _on_missile_hit(enemy: Enemy, point: Vector3, killed: bool) -> void:
	if killed:
		missile_kills += 1
		_kill(enemy, point)


func _on_missile_detonated(at: Vector3, size: float) -> void:
	fx.explosion(at, size * 0.55)
	turret.add_impulse(0.6)


func _kill(enemy: Enemy, point: Vector3) -> void:
	if enemy.wrecking or enemy.is_queued_for_deletion():
		return
	kills += 1
	score += enemy.score_value
	kill_flash = 0.22
	splash_text = "SPLASH  " + enemy.display
	splash_timer = 1.3
	if bool(enemy.data.get("wreck", false)):
		_wreck(enemy)
		return
	if enemy.is_boss:
		# Ripple of blasts down the hull rather than one sphere at the centre.
		var pts := enemy.volume_points()
		pts.shuffle()
		for i in pts.size():
			var v: Dictionary = pts[i]
			_pending_blasts.append({"pos": v["pos"], "size": float(v["radius"]) * 1.2,
					"t": _blast_clock + float(i) * 0.11})
		turret.add_impulse(6.0)
		_show_banner("TARGET DESTROYED", enemy.display, 3.0)
	else:
		fx.explosion(enemy.global_position, enemy.radius)
	enemy.queue_free()


## Capital ship death: it breaks up and falls into the sea over about nine
## seconds, with explosions that ride the wreck down, then one last flash.
func _wreck(enemy: Enemy) -> void:
	enemy.begin_wreck()
	turret.add_impulse(6.0)
	sensor_flash = maxf(sensor_flash, 0.45)
	_show_banner("TARGET DESTROYED", enemy.display, 4.0)
	var vols: Array = enemy.local_volumes()
	var ms: float = enemy.model_scale()
	var t := 0.0
	var n := 0
	while t < 8.2:
		var v: Dictionary = vols.pick_random()
		_pending_blasts.append({"enemy": enemy, "local": v["pos"],
				"size": float(v["radius"]) * ms * randf_range(0.6, 1.1),
				"fire": n % 4 == 0, "t": _blast_clock + t})
		n += 1
		# Starts as a scatter and builds to a constant ripple.
		t += lerpf(0.35, 0.07, clampf(t / 5.0, 0.0, 1.0))
	# Last ripple as it hits the water, end to end.
	for k in 16:
		var v2: Dictionary = vols.pick_random()
		_pending_blasts.append({"enemy": enemy, "local": v2["pos"],
				"size": float(v2["radius"]) * ms * 0.8, "t": _blast_clock + 8.2 + k * 0.04})
	_pending_blasts.append({"flash": 0.9, "t": _blast_clock + 8.45})
	_pending_blasts.append({"free": enemy, "t": _blast_clock + 8.9})


func _on_enemy_died(enemy: Enemy, killed_by_player: bool) -> void:
	if not killed_by_player:
		return


func _on_enemy_leaked(enemy: Enemy) -> void:
	leaks += 1
	hull = maxf(hull - enemy.threat, 0.0)
	turret.add_impulse(5.0)
	fx.explosion(Vector3(enemy.global_position.x, 6.0, enemy.global_position.z),
			enemy.radius * 1.4)
	enemy.queue_free()
	if hull <= 0.0:
		_game_over()


func _on_launch_requested(type_id: String, origin: Vector3, forward: Vector3) -> void:
	_spawn(type_id, origin, forward)
	fx.spark_burst(origin, 8, 1.6)


func _on_bay_opened(enemy: Enemy, count: int) -> void:
	if enemy.is_boss:
		flash_message("BAY OPEN  %d CONTACTS LAUNCHED" % count, 1.8)


# ---------------------------------------------------------------------------
# Loop
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_update_shader(delta)
	salvo_label_timer = maxf(salvo_label_timer - delta, 0.0)
	banner_timer = maxf(banner_timer - delta, 0.0)
	if banner_timer <= 0.0 and not _banner_queue.is_empty():
		var b: Array = _banner_queue.pop_front()
		_show_banner(String(b[0]), String(b[1]), float(b[2]))
	splash_timer = maxf(splash_timer - delta, 0.0)
	hit_flash = maxf(hit_flash - delta, 0.0)
	kill_flash = maxf(kill_flash - delta, 0.0)
	hud.queue_redraw()

	if _paused:
		return

	_run_pending_blasts(delta)

	if state == State.TITLE:
		# Slow idle sweep behind the title.
		title_time += delta
		turret.rotation.y -= delta * 0.12
		turret.mount.rotation.x = deg_to_rad(6.0 + sin(title_time * 0.4) * 3.0)
		return

	# Held-button state has to be polled: the turret is inside the SubViewport
	# and never sees input events itself.
	turret.missile_input = (state == State.RUNNING or state == State.BRIEF) \
			and Input.is_action_pressed("ciws_missile")

	if _demo:
		_run_demo_gunner(delta)

	match state:
		State.BRIEF:
			brief_timer -= delta
			if brief_timer <= 0.0:
				_start_wave(wave + 1)

		State.RUNNING:
			_queue_time += delta
			while not _queue.is_empty() and float(_queue[0]["t"]) <= _queue_time:
				var entry: Dictionary = _queue.pop_front()
				_spawn(String(entry["type"]))
			if _queue.is_empty() and live_enemies().is_empty() and _pending_blasts.is_empty():
				_wave_active = false
				score += 250 * wave
				state = State.BRIEF
				brief_timer = INTERMISSION
				wave_label = "WAVE %02d CLEAR - REARMING" % wave
				best_wave = maxi(best_wave, wave)
				best_score = maxi(best_score, score)
				_save_profile()

		State.OVER:
			pass


func _run_pending_blasts(delta: float) -> void:
	if _pending_blasts.is_empty():
		return
	_blast_clock += delta
	var i := 0
	while i < _pending_blasts.size():
		var b: Dictionary = _pending_blasts[i]
		if float(b["t"]) <= _blast_clock:
			_pending_blasts.remove_at(i)
			_fire_blast(b)
			continue
		i += 1


func _fire_blast(b: Dictionary) -> void:
	if b.has("flash"):
		sensor_flash = maxf(sensor_flash, float(b["flash"]))
		turret.add_impulse(6.0)
		return
	if b.has("free"):
		var f = b["free"]
		if f != null and is_instance_valid(f):
			(f as Node).queue_free()
		return
	var pos: Vector3
	if b.has("enemy"):
		# Follows the wreck as it falls.
		var raw = b["enemy"]
		if raw == null or not is_instance_valid(raw):
			return
		var en: Enemy = raw
		pos = en.model_to_global(b["local"])
		if bool(b.get("fire", false)):
			en.add_fire(en.to_local(pos), float(b["size"]) * 0.45)
	else:
		pos = b["pos"]
	fx.explosion(pos, float(b["size"]))
	turret.add_impulse(0.8)


## Closed-loop gunner used for attract mode and for eyeballing the game
## without a mouse. Picks the highest-threat contact, computes the ballistic
## intercept, slews to it and squeezes the trigger when the bore is on.
func _run_demo_gunner(delta: float) -> void:
	# Anything inside 900 m first, nearest first; otherwise the worst threat.
	var best: Enemy = null
	var best_score := -INF
	for e in live_enemies():
		if e.warping:
			continue
		var d: float = e.global_position.length()
		var s: float = (10000.0 - d) if d < 900.0 else (e.threat * 40.0 - d)
		if s > best_score:
			best_score = s
			best = e
	if best == null:
		turret.force_fire = false
		return

	var muzzle := turret.muzzle.global_position
	var rel: Vector3 = best.global_position - muzzle
	var t := _intercept_time(rel, best.velocity, Turret.MUZZLE_VELOCITY)
	var aim: Vector3 = best.global_position
	if t > 0.0:
		aim = best.global_position + best.velocity * t \
				+ Vector3.UP * (0.5 * BulletProjectile.GRAVITY * t * t)
	turret.slew_toward(aim, delta)

	var bore := -turret.muzzle.global_transform.basis.z
	var to_aim := (aim - muzzle).normalized()
	var off := rad_to_deg(acos(clampf(bore.dot(to_aim), -1.0, 1.0)))
	var range_m := rel.length()
	turret.force_fire = off < 1.6 and range_m < 2200.0

	# Exercise the missiles too: zoom and take a lock on anything far out or
	# tough, and dump the salvo whenever it is charged and there is a crowd.
	var wants_missile: bool = range_m > 900.0 or best.max_hp > 150.0
	turret.zoom_level = 1.0 if wants_missile else 0.0
	turret.missile_input = wants_missile and off < 2.0 and turret.missiles > 0
	if turret.salvo_ready() and turret.visible_contacts().size() >= 2:
		turret.request_salvo()


func _intercept_time(rel: Vector3, tvel: Vector3, speed: float) -> float:
	var a := tvel.dot(tvel) - speed * speed
	var b := 2.0 * rel.dot(tvel)
	var c := rel.dot(rel)
	if absf(a) < 0.0001:
		return -1.0 if absf(b) < 0.0001 else -c / b
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return -1.0
	disc = sqrt(disc)
	var best := -1.0
	for t in [(-b - disc) / (2.0 * a), (-b + disc) / (2.0 * a)]:
		if t > 0.0 and (best < 0.0 or t < best):
			best = t
	return best


func _update_shader(delta: float) -> void:
	if thermal == null:
		return
	var s: float = turret.shake_total() if turret != null else 0.0
	thermal.set_shader_parameter("shake_x", randf_range(-s, s) * 0.0035)
	thermal.set_shader_parameter("shake_y", randf_range(-s, s) * 0.0035)
	thermal.set_shader_parameter("polarity", polarity)
	sensor_flash = maxf(sensor_flash - delta * 1.7, 0.0)
	thermal.set_shader_parameter("flash", sensor_flash * sensor_flash)
	# The sensor washes out slightly when the gun is running.
	thermal.set_shader_parameter("gain", 1.35 + s * 0.05)


## All input is handled here, on the root node.
##
## The turret sits inside a SubViewport, and nothing pushed into the root
## viewport reaches a node in there, so aiming has to be forwarded explicitly.
## That is also why the whole control scheme lives in one place.
func _unhandled_input(event: InputEvent) -> void:
	if state == State.TITLE:
		if event.is_action_pressed("ciws_fire") or event.is_action_pressed("ciws_restart"):
			_begin()
		return

	if event is InputEventMouseMotion:
		if not _paused and state != State.OVER:
			turret.apply_mouse_motion((event as InputEventMouseMotion).relative)
		return

	# Restart first: on the game-over screen the left button is "reset", and it
	# must not also be read as a trigger pull.
	if state == State.OVER:
		if event.is_action_pressed("ciws_restart"):
			_restart()
		return

	if event.is_action_pressed("ciws_salvo"):
		var n := turret.request_salvo()
		if n > 0:
			flash_message("SALVO AWAY  %d TRACKS" % n, 2.0)
		elif turret.salvo_charge < 1.0:
			flash_message("SALVO CHARGING %d%%" % int(turret.salvo_charge * 100.0), 1.6)
		else:
			flash_message("NO CONTACTS IN FIELD", 1.6)
	elif event.is_action_pressed("ciws_zoom_in"):
		if _paused:
			_nudge_sensitivity(1.0)
		else:
			turret.nudge_zoom(0.2)
	elif event.is_action_pressed("ciws_zoom_out"):
		if _paused:
			_nudge_sensitivity(-1.0)
		else:
			turret.nudge_zoom(-0.2)
	elif event.is_action_pressed("ciws_polarity"):
		polarity = 1.0 - polarity
	elif event.is_action_pressed("ciws_pause"):
		_paused = not _paused
		_capture_mouse(not _paused)
		turret.set_enabled(not _paused)
		get_tree().paused = _paused


## Mouse sensitivity is adjusted with the wheel on the pause screen, so the
## game never needs the keyboard for setup either.
func _nudge_sensitivity(dir: float) -> void:
	var s: float = turret.mouse_sensitivity * (1.15 if dir > 0.0 else 1.0 / 1.15)
	turret.mouse_sensitivity = clampf(s, 0.0004, 0.012)


func _capture_mouse(v: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if v else Input.MOUSE_MODE_VISIBLE


func _game_over() -> void:
	state = State.OVER
	turret.set_enabled(false)
	_capture_mouse(false)
	best_wave = maxi(best_wave, wave)
	best_score = maxi(best_score, score)
	_save_profile()


func _restart() -> void:
	for c in enemies_root.get_children():
		c.queue_free()
	ballistics.clear_all()
	missile_smoke.clear_all()
	fx.clear_all()
	_pending_blasts.clear()
	sensor_flash = 0.0
	_warp_sound.stop()
	hull = HULL_MAX
	score = 0
	kills = 0
	leaks = 0
	hits = 0
	misses = 0
	missiles_fired = 0
	missile_kills = 0
	wave = 0
	salvo_label_timer = 0.0
	banner_timer = 0.0
	_banner_queue.clear()
	splash_timer = 0.0
	_queue.clear()
	turret.ammo = Turret.MAGAZINE
	turret.reloading = false
	turret.rounds_fired_total = 0
	turret.zoom_level = 0.0
	turret.force_fire = false
	turret.salvo_charge = 0.0
	turret.combo = 0
	turret.refill_missiles()
	turret.set_enabled(true)
	_capture_mouse(true)
	state = State.BRIEF
	brief_timer = 3.0
	wave_label = "SYSTEM READY"


# ---------------------------------------------------------------------------
# Profile
# ---------------------------------------------------------------------------

func _load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		best_wave = int(parsed.get("best_wave", 0))
		best_score = int(parsed.get("best_score", 0))


func _save_profile() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"best_wave": best_wave, "best_score": best_score}))
	f.close()


# ---------------------------------------------------------------------------
# Queried by the HUD
# ---------------------------------------------------------------------------

func accuracy() -> float:
	var shots := hits + misses
	return 0.0 if shots <= 0 else float(hits) / float(shots)


func paused() -> bool:
	return _paused
