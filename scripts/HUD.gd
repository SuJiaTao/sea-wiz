extends Control
## Fire-control overlay. Drawn at full resolution on top of the low-res thermal
## image, the way a real sensor overlay is composited over the video.

var game: Node = null

const C_MAIN := Color(0.93, 0.98, 0.93, 0.95)
const C_DIM := Color(0.62, 0.70, 0.62, 0.70)
const C_FAINT := Color(0.45, 0.52, 0.45, 0.45)
const C_WARN := Color(1.0, 1.0, 1.0, 1.0)

const RADAR_RANGE := 2400.0
const TRACK_CONE_DEG := 30.0

var _font: Font
var _blink: float = 0.0
var _tracked: Enemy = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	_blink += delta


func _txt(pos: Vector2, s: String, px: int = 13, col: Color = C_MAIN,
		align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(_font, pos, s, align, width, px, col)


func _draw() -> void:
	if game == null:
		return
	var sz := size
	var cx := sz.x * 0.5
	var cy := sz.y * 0.5

	var turret: Turret = game.turret
	var cam: Camera3D = turret.camera
	var shrink: float = float(game.container.stretch_shrink)

	if game.state == Game.State.TITLE:
		_draw_title(sz)
		return

	_pick_track(turret, cam)
	_draw_contacts(cam, shrink, sz)
	_draw_reticle(cx, cy, turret)
	_draw_lead(turret, cam, shrink, sz)
	_draw_lock(turret, cam, shrink, sz)
	_draw_salvo(turret, cam, shrink, sz)
	_draw_bearing_tape(sz, turret)
	_draw_radar(sz, turret)
	_draw_left_panel(sz, turret)
	_draw_right_panel(sz)
	_draw_boss_bar(sz)
	_draw_messages(sz)


# ---------------------------------------------------------------------------

func _pick_track(turret: Turret, cam: Camera3D) -> void:
	var bore := -cam.global_transform.basis.z
	var origin := cam.global_position
	var best: Enemy = null
	var best_score := -INF
	for e in game.live_enemies():
		var to: Vector3 = (e.global_position - origin)
		var d: float = to.length()
		if d < 1.0:
			continue
		var ang: float = rad_to_deg(acos(clampf(bore.dot(to / d), -1.0, 1.0)))
		if ang > TRACK_CONE_DEG:
			continue
		# Prefer on-axis and close.
		var s: float = -ang * 3.0 - d * 0.004 + e.threat * 0.5
		if s > best_score:
			best_score = s
			best = e
	if best == null:
		var nearest: Enemy = null
		var nd := INF
		for e in game.live_enemies():
			var d: float = e.global_position.length()
			if d < nd:
				nd = d
				nearest = e
		best = nearest
	_tracked = best


func _project(cam: Camera3D, shrink: float, world_pos: Vector3) -> Vector2:
	return cam.unproject_position(world_pos) * shrink


func _visible_ahead(cam: Camera3D, world_pos: Vector3) -> bool:
	return not cam.is_position_behind(world_pos)


func _draw_contacts(cam: Camera3D, shrink: float, sz: Vector2) -> void:
	var shown := 0
	for e in game.live_enemies():
		if shown > 14:
			break
		if not _visible_ahead(cam, e.global_position):
			continue
		var p := _project(cam, shrink, e.global_position)
		if p.x < -60 or p.y < -60 or p.x > sz.x + 60 or p.y > sz.y + 60:
			continue
		shown += 1
		var d: float = e.global_position.length()
		var is_track: bool = e == _tracked
		var col: Color = C_MAIN if is_track else C_DIM
		var half: float = clampf(e.radius * 900.0 / maxf(d, 1.0), 8.0, 90.0)
		_brackets(p, half, col, 2.0 if is_track else 1.0)
		if is_track:
			_txt(p + Vector2(half + 8, -half + 2), e.display, 12, col)
			_txt(p + Vector2(half + 8, -half + 17), "%d m" % int(d), 12, col)
			var closure: float = -e.velocity.dot(e.global_position.normalized())
			_txt(p + Vector2(half + 8, -half + 32), "%+d m/s" % int(closure), 12, col)
			var hp_frac: float = clampf(e.hp / maxf(e.max_hp, 1.0), 0.0, 1.0)
			draw_rect(Rect2(p + Vector2(-half, half + 6), Vector2(half * 2.0, 3.0)), C_FAINT)
			draw_rect(Rect2(p + Vector2(-half, half + 6), Vector2(half * 2.0 * hp_frac, 3.0)), col)
		elif d < 600.0:
			_txt(p + Vector2(half + 5, 4), "%d" % int(d), 10, C_FAINT)


func _brackets(p: Vector2, h: float, col: Color, w: float) -> void:
	var t := h * 0.35
	# Four corner brackets.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var c := p + Vector2(sx * h, sy * h)
			draw_line(c, c - Vector2(sx * t, 0), col, w)
			draw_line(c, c - Vector2(0, sy * t), col, w)


func _draw_reticle(cx: float, cy: float, turret: Turret) -> void:
	var c := Vector2(cx, cy)
	var col := C_MAIN
	# Open cross with a bore dot.
	draw_line(c + Vector2(-26, 0), c + Vector2(-8, 0), col, 1.5)
	draw_line(c + Vector2(8, 0), c + Vector2(26, 0), col, 1.5)
	draw_line(c + Vector2(0, -26), c + Vector2(0, -8), col, 1.5)
	draw_line(c + Vector2(0, 8), c + Vector2(0, 26), col, 1.5)
	draw_circle(c, 1.5, col)
	# Dispersion circle: roughly the beaten zone at 1000 m.
	var spread_px := tan(deg_to_rad(turret.dispersion_deg * 2.5)) / tan(deg_to_rad(turret.camera.fov * 0.5)) * (size.y * 0.5)
	draw_arc(c, maxf(spread_px, 4.0), 0, TAU, 32, C_FAINT, 1.0)
	# Hit marker: a tick on every hit, a bigger heavier one on a kill.
	if game.kill_flash > 0.0:
		_hit_ticks(c, 14.0, 30.0, 2.5, Color(1, 1, 1, clampf(game.kill_flash * 5.0, 0, 1)))
	elif game.hit_flash > 0.0:
		_hit_ticks(c, 11.0, 19.0, 1.5, Color(1, 1, 1, 0.9))
	# Firing state.
	if turret.firing:
		draw_arc(c, 34, 0, TAU, 40, Color(1, 1, 1, 0.35 + 0.25 * sin(_blink * 60.0)), 1.0)


func _hit_ticks(c: Vector2, r0: float, r1: float, w: float, col: Color) -> void:
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var d := Vector2(sx, sy).normalized()
			draw_line(c + d * r0, c + d * r1, col, w)


func _draw_lead(turret: Turret, cam: Camera3D, shrink: float, sz: Vector2) -> void:
	if _tracked == null:
		return
	var muzzle := turret.muzzle.global_position
	var rel: Vector3 = _tracked.global_position - muzzle
	var t := _intercept_time(rel, _tracked.velocity, Turret.MUZZLE_VELOCITY)
	if t <= 0.0:
		return
	var aim: Vector3 = _tracked.global_position + _tracked.velocity * t \
			+ Vector3.UP * (0.5 * BulletProjectile.GRAVITY * t * t)
	if not _visible_ahead(cam, aim):
		return
	var p := _project(cam, shrink, aim)
	if p.x < 0 or p.y < 0 or p.x > sz.x or p.y > sz.y:
		return
	# Lead pipper: a diamond you put the bore on.
	var r := 9.0
	var pts := PackedVector2Array([
		p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0),
		p + Vector2(0, -r)])
	draw_polyline(pts, C_MAIN, 1.5)
	draw_line(Vector2(size.x * 0.5, size.y * 0.5), p, Color(0.9, 1.0, 0.9, 0.18), 1.0)
	_txt(p + Vector2(12, 16), "TOF %.2fs" % t, 11, C_DIM)


## Seeker box. Converges onto the target as the lock builds, so you can read
## how long you still have to hold the bore on it.
func _draw_lock(turret: Turret, cam: Camera3D, shrink: float, sz: Vector2) -> void:
	var c := Vector2(sz.x * 0.5, sz.y * 0.5)

	if turret.missile_input and not turret.lock_denied_reason.is_empty():
		_center(c + Vector2(0, 58), turret.lock_denied_reason, 14,
				Color(1, 1, 1, 0.45 + 0.35 * sin(_blink * 9.0)))
		return

	# Seeker gate: shows where the cone is while you are holding the button.
	if turret.missile_input and turret.zoom_active():
		var gate := tan(deg_to_rad(Turret.LOCK_CONE_DEG)) \
				/ tan(deg_to_rad(cam.fov * 0.5)) * (sz.y * 0.5)
		draw_arc(c, maxf(gate, 10.0), 0, TAU, 40, C_FAINT, 1.0)

	var raw = turret.lock_target
	if raw == null or not is_instance_valid(raw):
		return
	var tgt: Enemy = raw
	if not tgt.alive:
		return
	if not _visible_ahead(cam, tgt.global_position):
		return
	var p := _project(cam, shrink, tgt.global_position)
	var prog: float = clampf(turret.lock_progress, 0.0, 1.0)
	# Box starts wide and closes in.
	var h: float = lerpf(64.0, 20.0, prog)
	var col := Color(1, 1, 1, 0.55 + 0.45 * prog)
	_brackets(p, h, col, 2.0)
	draw_arc(p, h + 10.0, -PI * 0.5, -PI * 0.5 + TAU * prog, 40, col, 2.0)
	# Below the box, so it never collides with the contact label to its right.
	_center(p + Vector2(0, h + 30.0), "SEEKER %d%%" % int(prog * 100.0), 12, col)


## While a ripple is leaving the cells, every assigned track gets a box.
func _draw_salvo(turret: Turret, cam: Camera3D, shrink: float, sz: Vector2) -> void:
	if turret.salvo_targets.is_empty():
		return
	for t in turret.salvo_targets:
		if t == null or not is_instance_valid(t):
			continue
		var e := t as Enemy
		if not e.alive:
			continue
		if not _visible_ahead(cam, e.global_position):
			continue
		var p := _project(cam, shrink, e.global_position)
		if p.x < -40 or p.y < -40 or p.x > sz.x + 40 or p.y > sz.y + 40:
			continue
		var pulse: float = 0.6 + 0.4 * sin(_blink * 14.0)
		_brackets(p, 22.0, Color(1, 1, 1, pulse), 2.0)
		draw_line(p + Vector2(-8, 0), p + Vector2(8, 0), Color(1, 1, 1, pulse), 1.0)
		draw_line(p + Vector2(0, -8), p + Vector2(0, 8), Color(1, 1, 1, pulse), 1.0)


func _intercept_time(rel: Vector3, tvel: Vector3, speed: float) -> float:
	var a := tvel.dot(tvel) - speed * speed
	var b := 2.0 * rel.dot(tvel)
	var c := rel.dot(rel)
	if absf(a) < 0.0001:
		if absf(b) < 0.0001:
			return -1.0
		return -c / b
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return -1.0
	disc = sqrt(disc)
	var t1 := (-b - disc) / (2.0 * a)
	var t2 := (-b + disc) / (2.0 * a)
	var best := -1.0
	for t in [t1, t2]:
		if t > 0.0 and (best < 0.0 or t < best):
			best = t
	return best


func _draw_bearing_tape(sz: Vector2, turret: Turret) -> void:
	var bearing := turret.bearing_deg()
	var y := 26.0
	var half_w := sz.x * 0.32
	var span := 70.0    # degrees shown across the tape
	draw_line(Vector2(sz.x * 0.5 - half_w, y), Vector2(sz.x * 0.5 + half_w, y), C_FAINT, 1.0)
	var start := int(floor((bearing - span * 0.5) / 5.0)) * 5
	for i in range(0, int(span / 5.0) + 2):
		var deg := float(start + i * 5)
		var off := wrapf(deg - bearing, -180.0, 180.0)
		if absf(off) > span * 0.5:
			continue
		var x := sz.x * 0.5 + (off / span) * half_w * 2.0
		var major := int(fposmod(deg, 30.0)) == 0
		draw_line(Vector2(x, y), Vector2(x, y + (10.0 if major else 5.0)), C_DIM, 1.0)
		if major:
			_txt(Vector2(x - 14, y + 26), "%03d" % int(fposmod(deg, 360.0)), 12, C_DIM)
	# Centre caret.
	draw_polyline(PackedVector2Array([
		Vector2(sz.x * 0.5 - 6, y - 9), Vector2(sz.x * 0.5, y - 1),
		Vector2(sz.x * 0.5 + 6, y - 9)]), C_MAIN, 2.0)
	_txt(Vector2(sz.x * 0.5 - 24, y - 14), "%03d" % int(bearing), 14, C_MAIN)
	_txt(Vector2(sz.x * 0.5 + half_w + 12, y + 5), "EL %+03d" % int(turret.elevation_deg()), 12, C_DIM)


func _draw_radar(sz: Vector2, turret: Turret) -> void:
	var r := 96.0
	var c := Vector2(sz.x - r - 34.0, sz.y - r - 34.0)
	draw_arc(c, r, 0, TAU, 64, C_DIM, 1.0)
	for f in [0.33, 0.66]:
		draw_arc(c, r * f, 0, TAU, 48, C_FAINT, 1.0)
	for i in 12:
		var a := TAU * float(i) / 12.0
		var v := Vector2(sin(a), -cos(a))
		draw_line(c + v * (r - 6.0), c + v * r, C_FAINT, 1.0)
	# Own ship + gun bearing wedge (display is gun-up).
	draw_circle(c, 2.5, C_MAIN)
	var fov_half := deg_to_rad(turret.camera.fov * 0.5)
	draw_line(c, c + Vector2(sin(-fov_half), -cos(-fov_half)) * r, C_FAINT, 1.0)
	draw_line(c, c + Vector2(sin(fov_half), -cos(fov_half)) * r, C_FAINT, 1.0)

	var bearing_rad := deg_to_rad(turret.bearing_deg())
	for e in game.live_enemies():
		var p3: Vector3 = e.global_position
		var d: float = Vector2(p3.x, p3.z).length()
		var rng: float = clampf(d / RADAR_RANGE, 0.0, 1.0)
		# World bearing of the contact, then rotate into gun-up frame.
		var world_b := atan2(p3.x, -p3.z)
		var rel := wrapf(world_b - bearing_rad, -PI, PI)
		var v := Vector2(sin(rel), -cos(rel)) * (rng * r)
		var col: Color = C_MAIN if e == _tracked else C_DIM
		var s: float = 4.0 if e.radius > 12.0 else 2.5
		draw_rect(Rect2(c + v - Vector2(s, s), Vector2(s * 2, s * 2)), col, e == _tracked)
		if e.radius > 25.0:
			draw_arc(c + v, 9.0, 0, TAU, 16, col, 1.0)
	_txt(c + Vector2(-r, r + 18), "SURVEILLANCE  %d km" % int(RADAR_RANGE / 1000.0), 11, C_FAINT)


func _draw_left_panel(sz: Vector2, turret: Turret) -> void:
	var x := 28.0
	var y := sz.y - 232.0

	# Ready missile cells, as pips.
	_txt(Vector2(x, y), "CELLS", 12, C_DIM)
	for i in Turret.MISSILE_CAPACITY:
		var r := Rect2(Vector2(x + 62 + i * 16, y - 10), Vector2(11, 12))
		if i < turret.missiles:
			draw_rect(r, C_MAIN)
		else:
			draw_rect(r, C_FAINT, false, 1.0)

	# Salvo charge, earned with the gun.
	_txt(Vector2(x, y + 22), "SALVO", 12, C_DIM)
	var ready: bool = turret.salvo_ready()
	var charge_col: Color = Color(1, 1, 1, 0.55 + 0.45 * sin(_blink * 7.0)) if ready else C_MAIN
	_bar(Vector2(x + 62, y + 12), Vector2(128, 12), turret.salvo_charge, charge_col)
	if ready:
		_txt(Vector2(x + 198, y + 22), "READY", 12, charge_col)
	else:
		_txt(Vector2(x + 198, y + 22), "%d%%" % int(turret.salvo_charge * 100.0), 12, C_FAINT)

	if turret.combo > 1:
		_txt(Vector2(x, y + 42), "COMBO x%d" % turret.combo, 14,
				Color(1, 1, 1, 0.6 + 0.4 * clampf(turret.combo_timer / Turret.COMBO_WINDOW, 0, 1)))

	y += 64.0

	_txt(Vector2(x, y), "HULL", 12, C_DIM)
	_bar(Vector2(x, y + 8), Vector2(190, 12), game.hull / Game.HULL_MAX,
			C_WARN if game.hull < 35.0 else C_MAIN)
	_txt(Vector2(x + 196, y + 18), "%d%%" % int(game.hull), 12, C_MAIN)

	_txt(Vector2(x, y + 44), "MAGAZINE", 12, C_DIM)
	var ammo_frac := float(turret.ammo) / float(Turret.MAGAZINE)
	_bar(Vector2(x, y + 52), Vector2(190, 12), ammo_frac,
			C_WARN if ammo_frac < 0.15 else C_MAIN)
	_txt(Vector2(x + 196, y + 62), "%d" % turret.ammo, 12, C_MAIN)

	if turret.reloading:
		var blink := 0.5 + 0.5 * sin(_blink * 10.0)
		_txt(Vector2(x, y + 90), "RELOADING", 16, Color(1, 1, 1, blink))
	elif turret.spin > 0.05:
		_txt(Vector2(x, y + 90), "BARRELS %d%%" % int(turret.spin * 100.0), 14, C_DIM)

	_txt(Vector2(x, y + 116), "LEVEL %02d" % game.wave, 18, C_MAIN)
	_txt(Vector2(x, y + 138), "SCORE %d" % game.score, 14, C_DIM)
	_txt(Vector2(x, y + 156), "HIT %d%%   KILLS %d   LEAKS %d"
			% [int(game.accuracy() * 100.0), game.kills, game.leaks], 12, C_FAINT)


func _draw_right_panel(sz: Vector2) -> void:
	var x := sz.x - 260.0
	var y := 74.0
	_txt(Vector2(x, y), "MODE  " + ("BLACK HOT" if game.polarity > 0.5 else "WHITE HOT"), 12, C_DIM)
	_txt(Vector2(x, y + 18), "CONTACTS  %02d" % game.live_enemies().size(), 12, C_DIM)
	_txt(Vector2(x, y + 36), "BEST  W%02d / %d" % [game.best_wave, game.best_score], 12, C_FAINT)
	_txt(Vector2(x + 140, y), "MSL  %d / %d" % [game.missile_kills, game.missiles_fired],
			12, C_FAINT)
	var turret: Turret = game.turret
	_txt(Vector2(x, y + 54), "ZOOM  %.1fx" % (Turret.FOV_WIDE / maxf(turret.camera.fov, 1.0)),
			12, C_DIM)
	_txt(Vector2(x, y + 78), "MOVE MOUSE  TRAVERSE", 11, C_FAINT)
	_txt(Vector2(x, y + 94), "LEFT  GUN        RIGHT  ZOOM", 11, C_FAINT)
	_txt(Vector2(x, y + 110), "WHEEL ZOOM       MIDDLE RELOAD", 11, C_FAINT)
	_txt(Vector2(x, y + 126), "SIDE 1 / Q  MISSILE  (ZOOM FIRST)", 11, C_FAINT)
	_txt(Vector2(x, y + 142), "SIDE 2 / E  SALVO", 11, C_FAINT)
	_txt(Vector2(x, y + 158), "F POLARITY       ESC PAUSE", 11, C_FAINT)


func _draw_messages(sz: Vector2) -> void:
	var cx := sz.x * 0.5
	if game.state == Game.State.OVER:
		_center(Vector2(cx, sz.y * 0.42), "MOUNT DESTROYED", 40, C_WARN)
		_center(Vector2(cx, sz.y * 0.42 + 40),
				"LEVEL %02d   SCORE %d   HIT %d%%"
				% [game.wave, game.score, int(game.accuracy() * 100.0)], 18, C_MAIN)
		_center(Vector2(cx, sz.y * 0.42 + 72), "CLICK TO RESET", 16,
				Color(1, 1, 1, 0.4 + 0.4 * sin(_blink * 6.0)))
		return
	if game.paused():
		_center(Vector2(cx, sz.y * 0.40), "PAUSED", 36, C_MAIN)
		_center(Vector2(cx, sz.y * 0.40 + 34), "ESC TO RESUME", 14, C_DIM)
		_center(Vector2(cx, sz.y * 0.40 + 74), "MOUSE SENSITIVITY", 13, C_DIM)
		var s: float = game.turret.mouse_sensitivity
		_center(Vector2(cx, sz.y * 0.40 + 96), "%.1f" % (s * 1000.0), 24, C_MAIN)
		_bar(Vector2(cx - 90.0, sz.y * 0.40 + 106),
				Vector2(180, 10), inverse_lerp(0.0004, 0.012, s), C_MAIN)
		_center(Vector2(cx, sz.y * 0.40 + 140), "SCROLL WHEEL TO ADJUST", 12, C_FAINT)
		return
	# Level / warning banner: quick fade in, fade out over the last 0.6 s.
	if game.banner_timer > 0.0:
		var a: float = clampf(game.banner_timer / 0.6, 0.0, 1.0)
		var warn: bool = game.banner_title == "WARNING"
		if warn:
			a *= 0.6 + 0.4 * sin(_blink * 10.0)
		_center(Vector2(cx, sz.y * 0.24), game.banner_title, 34, Color(1, 1, 1, a))
		_center(Vector2(cx, sz.y * 0.24 + 30), game.banner_sub, 17,
				Color(0.85, 0.92, 0.85, a * 0.9))

	# Kill confirm under the reticle.
	if game.splash_timer > 0.0:
		_center(Vector2(cx, sz.y * 0.33 + 24), game.splash_text, 14,
				Color(1, 1, 1, clampf(game.splash_timer * 1.5, 0.0, 1.0)))

	if game.salvo_label_timer > 0.0:
		# Above the reticle cluster, so it never lands on the seeker box,
		# contact labels or the kill confirm.
		_center(Vector2(cx, sz.y * 0.33), game.salvo_label, 17,
				Color(1, 1, 1, clampf(game.salvo_label_timer, 0.0, 1.0)))

	if game.state == Game.State.BRIEF:
		var a: float = 0.55 + 0.45 * sin(_blink * 4.0)
		_center(Vector2(cx, sz.y * 0.30), game.wave_label, 24, Color(1, 1, 1, a))
		var nxt: int = game.wave + 1
		_center(Vector2(cx, sz.y * 0.30 + 30),
				"NEXT  LEVEL %02d  %s  IN %d" % [nxt, game.level_name(nxt), int(ceil(game.brief_timer))],
				16, C_DIM)


## Integrity bar for capital ships, under the bearing tape.
func _draw_boss_bar(sz: Vector2) -> void:
	var boss: Enemy = null
	for e in game.live_enemies():
		if e.is_boss:
			boss = e
			break
	if boss == null:
		return
	var w := 440.0
	var x := sz.x * 0.5 - w * 0.5
	var y := 84.0
	var frac: float = clampf(boss.hp / maxf(boss.max_hp, 1.0), 0.0, 1.0)
	_txt(Vector2(x, y - 6), boss.display, 13, C_MAIN)
	_txt(Vector2(x + w - 110, y - 6), "INTEGRITY %d%%" % int(ceil(frac * 100.0)), 12, C_DIM)
	_bar(Vector2(x, y), Vector2(w, 10), frac, C_WARN if frac < 0.25 else C_MAIN)
	_txt(Vector2(x, y + 24), "%d m   BEARING %03d" % [int(boss.global_position.length()),
			game.bearing_to(boss.global_position)], 11, C_FAINT)


func _draw_title(sz: Vector2) -> void:
	var cx := sz.x * 0.5
	var y := sz.y * 0.36
	_center(Vector2(cx, y), "PHALANX  CIWS", 64, C_MAIN)
	_center(Vector2(cx, y + 34), "CLOSE IN WEAPON SYSTEM", 15, C_DIM)
	_center(Vector2(cx, y + 64), "You are the gun. Hold the line.", 16, C_DIM)
	_center(Vector2(cx, sz.y * 0.64), "CLICK TO ENGAGE", 20,
			Color(1, 1, 1, 0.45 + 0.45 * sin(_blink * 3.0)))
	if game.best_wave > 0:
		_center(Vector2(cx, sz.y * 0.64 + 30),
				"BEST  LEVEL %02d   %d PTS" % [game.best_wave, game.best_score], 13, C_FAINT)
	var by := sz.y - 64.0
	_center(Vector2(cx, by), "MOUSE  AIM      LEFT  GUN      RIGHT / WHEEL  ZOOM      MIDDLE  RELOAD", 12, C_FAINT)
	_center(Vector2(cx, by + 20), "SIDE 1 / Q  LOCK MISSILE (ZOOMED)      SIDE 2 / E  SALVO      ESC  PAUSE", 12, C_FAINT)


func _center(pos: Vector2, s: String, size_px: int, col: Color) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string(_font, pos - Vector2(w * 0.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


func _bar(pos: Vector2, dim: Vector2, frac: float, col: Color) -> void:
	draw_rect(Rect2(pos, dim), C_FAINT, false, 1.0)
	draw_rect(Rect2(pos + Vector2(2, 2), Vector2((dim.x - 4) * clampf(frac, 0, 1), dim.y - 4)), col)
