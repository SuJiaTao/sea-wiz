extends HUDPanel
class_name TrackHUD

const RADAR_RANGE: float = 4000.0
const METRES_PER_KM: float = 1000.0
const SCOPE_RADIUS: float = 96.0
const SCOPE_MARGIN: float = 34.0
const SCOPE_TICKS: int = 12
const SCOPE_TICK_LENGTH: float = 6.0
const CLOUD_MIN_METRES: float = 260.0
const CLOUD_MIN_PIXELS: float = 7.0
const CLOUD_PUFFS: int = 5
const CLOUD_SPREAD: float = 0.55
const CLOUD_ALPHA: float = 0.16
const MARKER_SIZE: float = 7.0
const MARKER_LIFT: float = 14.0
const FOCUS_CONE_DEG: float = 6.0
const FOCUS_GROWTH: float = 1.3
const EDGE_MARGIN: float = 28.0
const EDGE_ARROW: float = 9.0
const GATE_MIN: float = 10.0
const GATE_MAX: float = 70.0
const GATE_OPEN: float = 2.2
const GATE_SCALE: float = 1.3
const LOCK_GROW_TIME: float = 0.2
const LOCK_WIDTH: float = 2.0
const LOCK_DIAMOND_REACH: float = 1.3
const LEAD_PIP_RADIUS: float = 5.0
const LEAD_PIP_SEGMENTS: int = 16
const LEAD_FITTING := &"fire_control"
const RADAR_FITTING := &"radar"
const CLASS_SYMBOL: float = 3.5
const MISSILE_MARKER: float = 9.0
const MISSILE_LABEL := "VAMPIRE"
const MISSILE_LABEL_SIZE: int = 11
const MISSILE_BLINK_RATE: float = 4.0
const MISSILE_BLINK_DUTY: float = 0.5
const LEADER_SECONDS: float = 4.0
const LEADER_MAX_SHARE: float = 0.6
const LEADER_MIN_PIXELS: float = 2.0
const STALE_SECONDS: float = 2.2
const MISSILE_COLOUR := Color(1.0, 0.58, 0.18, 0.95)
const MISSILE_FAINT := Color(1.0, 0.58, 0.18, 0.55)
const SCOPE_MISSILE_RADIUS: float = 3.5
const SCOPE_AIRCRAFT_SIZE: float = 4.0
const JAM_STROBES: int = 9
const JAM_LABEL := "JAMMED"
const HOMING_COLOUR := Color(1.0, 0.2, 0.15, 0.95)

@export var turret: Turret
@export var tracks: TrackManager
@export var spotter: Spotter
@export var gun_director: GunDirector
@export var fire_control: FireControl
@export var loadout: ShipLoadout
## Targets our missiles are flying at keep a red diamond until the missile
## hits, misses or is decoyed.
@export var launcher: MissileLauncher

var _clock: float = 0.0
var _lock_age: float = 0.0


func _ready() -> void:
	fire_control.locked_on.connect(_on_locked_on)


func _update_hud(delta: float) -> void:
	_clock += delta
	_lock_age += delta


func _draw() -> void:
	for enemy in spotter.marked_enemies():
		_draw_marker(enemy)
	_draw_lock()
	if loadout.is_fitted(RADAR_FITTING):
		_draw_scope()


func _on_locked_on(_enemy: AbstractEnemy) -> void:
	_lock_age = 0.0


func _project(world_position: Vector3) -> Vector2:
	return _project_world(turret.camera, world_position)


func _on_screen(world_position: Vector3) -> bool:
	if turret.camera.is_position_behind(world_position):
		return false
	return Rect2(Vector2.ZERO, size).has_point(_project(world_position))


func _screen_radius(enemy: AbstractEnemy) -> float:
	var edge := enemy.global_position + turret.camera.global_basis.x * enemy.hud_radius
	return _project(enemy.global_position).distance_to(_project(edge))


func _draw_marker(enemy: AbstractEnemy) -> void:
	if not _on_screen(enemy.global_position):
		_draw_edge_arrow(enemy.global_position, _marker_colour(enemy))
		return
	var point := _project(enemy.global_position)
	if enemy.contact_kind == AbstractEnemy.ContactKind.MISSILE:
		_draw_missile_marker(point, enemy)
	else:
		_draw_aircraft_marker(point, enemy)


func _draw_aircraft_marker(point: Vector2, enemy: AbstractEnemy) -> void:
	var top := point - Vector2(0, _screen_radius(enemy) + MARKER_LIFT)
	var focused := _is_focused(enemy)
	var arrow := MARKER_SIZE * (FOCUS_GROWTH if focused else 1.0)
	draw_colored_polygon(PackedVector2Array([
		top + Vector2(-arrow, -arrow),
		top + Vector2(arrow, -arrow),
		top
	]), MAIN if focused else FAINT)


func _is_focused(enemy: AbstractEnemy) -> bool:
	if fire_control.is_locked() and fire_control.locked == enemy:
		return true
	var eye := turret.camera.global_position
	var sight := -turret.camera.global_basis.z
	var at_target := rad_to_deg(sight.angle_to(enemy.global_position - eye))
	var at_lead := rad_to_deg(sight.angle_to(gun_director.lead_point(enemy) - eye))
	return minf(at_target, at_lead) <= FOCUS_CONE_DEG


func _draw_missile_marker(point: Vector2, enemy: AbstractEnemy) -> void:
	var reach := _screen_radius(enemy) + MISSILE_MARKER
	var colour := _marker_colour(enemy)
	draw_arc(point, reach, 0, TAU, 24, colour, 2.0)
	_text(point + Vector2(reach + 6.0, -reach), MISSILE_LABEL, MISSILE_LABEL_SIZE, colour)


func _diamond(point: Vector2, reach: float) -> PackedVector2Array:
	return PackedVector2Array([
		point + Vector2(0, -reach),
		point + Vector2(reach, 0),
		point + Vector2(0, reach),
		point + Vector2(-reach, 0),
		point + Vector2(0, -reach)
	])


func _marker_colour(enemy: AbstractEnemy) -> Color:
	if enemy.contact_kind == AbstractEnemy.ContactKind.MISSILE:
		return MISSILE_COLOUR if _is_focused(enemy) or _blink_on() else MISSILE_FAINT
	return MAIN if _is_focused(enemy) else FAINT


func _blink_on() -> bool:
	return fmod(_clock * MISSILE_BLINK_RATE, 1.0) < MISSILE_BLINK_DUTY


func _draw_edge_arrow(world_position: Vector3, colour: Color) -> void:
	var local := turret.camera.global_transform.affine_inverse() * world_position
	var direction := Vector2(local.x, -local.y).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	var centre := size * 0.5
	var reach := (centre - Vector2.ONE * EDGE_MARGIN) / direction.abs().max(Vector2.ONE * 0.001)
	var tip := centre + direction * minf(reach.x, reach.y)
	var side := direction.orthogonal() * EDGE_ARROW * 0.6
	draw_colored_polygon(PackedVector2Array([
		tip, tip - direction * EDGE_ARROW + side, tip - direction * EDGE_ARROW - side
	]), colour)


func _draw_lock() -> void:
	var homing := launcher.homing_targets()
	for target in homing:
		if _on_screen(target.global_position):
			_draw_gate(target, 1.0, HOMING_COLOUR)
	if not fire_control.is_locked():
		return
	var enemy := fire_control.locked
	if not _on_screen(enemy.global_position):
		return
	if not homing.has(enemy):
		_draw_gate(enemy, clampf(_lock_age / LOCK_GROW_TIME, 0.0, 1.0), MAIN)
	if loadout.is_fitted(LEAD_FITTING):
		var lead := gun_director.lead_point(enemy)
		if not turret.camera.is_position_behind(lead):
			draw_arc(_project(lead), LEAD_PIP_RADIUS, 0, TAU, LEAD_PIP_SEGMENTS, MAIN, LOCK_WIDTH)


func _draw_gate(enemy: AbstractEnemy, grow: float, colour: Color) -> void:
	var half := clampf(_screen_radius(enemy) * GATE_SCALE, GATE_MIN, GATE_MAX) * lerpf(GATE_OPEN, 1.0, grow)
	draw_polyline(_diamond(_project(enemy.global_position), half * LOCK_DIAMOND_REACH), colour, LOCK_WIDTH)


func _draw_scope() -> void:
	var centre := Vector2(size.x - SCOPE_RADIUS - SCOPE_MARGIN, size.y - SCOPE_RADIUS - SCOPE_MARGIN)
	draw_arc(centre, SCOPE_RADIUS, 0, TAU, 64, DIM)
	for i in SCOPE_TICKS:
		var tick := TAU * float(i) / float(SCOPE_TICKS)
		var direction := Vector2(sin(tick), -cos(tick))
		draw_line(centre + direction * (SCOPE_RADIUS - SCOPE_TICK_LENGTH), centre + direction * SCOPE_RADIUS, FAINT)
	draw_circle(centre, 2.5, MAIN)
	_draw_field_of_view(centre)

	if tracks.search_radar.jammed():
		_draw_jamming(centre)
		return
	var marked := spotter.marked_enemies()
	for track in tracks.tracks():
		if not _belongs_to_marked(track, marked):
			if track.confirmed and loadout.can_classify():
				_draw_class_symbol(_scope_point(centre, track.position), track.kind)
			else:
				_draw_cloud(centre, track)
			if track.confirmed:
				_draw_leader(centre, track.position, track.velocity, Color(DIM, CLOUD_ALPHA * 3.0))
	for enemy in marked:
		if not _in_scope(enemy.global_position):
			continue
		var at := _scope_point(centre, enemy.global_position)
		_draw_leader(centre, enemy.global_position, enemy.velocity, DIM)
		if enemy.contact_kind == AbstractEnemy.ContactKind.MISSILE:
			draw_arc(at, SCOPE_MISSILE_RADIUS, 0, TAU, 16, MISSILE_COLOUR if _blink_on() else MISSILE_FAINT, 1.5)
		else:
			_draw_triangle(at, SCOPE_AIRCRAFT_SIZE, MAIN)

	_text(
		centre + Vector2(-SCOPE_RADIUS, SCOPE_RADIUS + 18),
		"HEAT  %.1f km   MARKED %d" % [RADAR_RANGE / METRES_PER_KM, marked.size()], 11, FAINT
	)


## Jamming smears the scope with bright strobes along random bearings.
func _draw_jamming(centre: Vector2) -> void:
	for strobe in JAM_STROBES:
		var bearing := randf() * TAU
		var direction := Vector2(sin(bearing), -cos(bearing))
		var near := randf() * SCOPE_RADIUS * 0.3
		draw_line(centre + direction * near, centre + direction * SCOPE_RADIUS, Color(DIM, randf_range(0.15, 0.5)), randf_range(1.0, 3.0))
	_text(centre + Vector2(-SCOPE_RADIUS, SCOPE_RADIUS + 18), JAM_LABEL, 11, MAIN if _blink_on() else FAINT)


func _draw_triangle(at: Vector2, half: float, colour: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(0, -half), at + Vector2(half, half), at + Vector2(-half, half)
	]), colour)


func _draw_class_symbol(at: Vector2, kind: RadarTrack.Kind) -> void:
	if kind == RadarTrack.Kind.MISSILE:
		draw_polyline(_diamond(at, CLASS_SYMBOL), MAIN if _blink_on() else DIM, 1.5)
	elif kind == RadarTrack.Kind.AIRCRAFT:
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(0, -CLASS_SYMBOL), at + Vector2(CLASS_SYMBOL, CLASS_SYMBOL),
			at + Vector2(-CLASS_SYMBOL, CLASS_SYMBOL)
		]), DIM)
	else:
		draw_rect(Rect2(at - Vector2.ONE * CLASS_SYMBOL, Vector2.ONE * CLASS_SYMBOL * 2.0), DIM)


func _scope_point(centre: Vector2, world_position: Vector3) -> Vector2:
	var offset := world_position - turret.global_position
	var distance := Vector2(offset.x, offset.z).length()
	var angle := wrapf(atan2(offset.x, -offset.z) - deg_to_rad(turret.bearing_deg()), -PI, PI)
	var reach := clampf(distance / RADAR_RANGE, 0.0, 1.0) * SCOPE_RADIUS
	return centre + Vector2(sin(angle), -cos(angle)) * reach


func _draw_leader(centre: Vector2, world_position: Vector3, velocity: Vector3, colour: Color) -> void:
	var start := _scope_point(centre, world_position)
	var tip := _scope_point(centre, world_position + velocity * LEADER_SECONDS)
	var leader := (tip - start).limit_length(SCOPE_RADIUS * LEADER_MAX_SHARE)
	if leader.length() >= LEADER_MIN_PIXELS:
		draw_line(start, start + leader, colour, 1.0)


func _belongs_to_marked(track: RadarTrack, marked: Array[AbstractEnemy]) -> bool:
	for enemy in marked:
		if track.follows(enemy):
			return true
	return false


## Marked contacts past the scope's edge are left off rather than pinned to
## the rim, where they would read as closer than they are.
func _in_scope(world_position: Vector3) -> bool:
	var offset := world_position - turret.global_position
	return Vector2(offset.x, offset.z).length() <= RADAR_RANGE


func _draw_cloud(centre: Vector2, track: RadarTrack) -> void:
	var metres := maxf(track.uncertainty, CLOUD_MIN_METRES)
	var radius := maxf(metres / RADAR_RANGE * SCOPE_RADIUS, CLOUD_MIN_PIXELS)
	var point := _scope_point(centre, track.position)
	var freshness := clampf(1.0 - track.since_update / STALE_SECONDS, 0.2, 1.0)
	var scatter := RandomNumberGenerator.new()
	scatter.seed = track.id
	for i in CLOUD_PUFFS:
		var drift := Vector2(scatter.randf_range(-1, 1), scatter.randf_range(-1, 1)) * radius * CLOUD_SPREAD
		var puff := radius * scatter.randf_range(0.5, 1.0)
		draw_circle(point + drift, puff, Color(DIM, CLOUD_ALPHA * freshness))


func _draw_field_of_view(centre: Vector2) -> void:
	var camera := turret.camera
	var viewport_size := Vector2(camera.get_viewport().get_visible_rect().size)
	var edge_ray := camera.project_ray_normal(Vector2(0, viewport_size.y * 0.5))
	var half_fov := acos(clampf((-camera.global_basis.z).dot(edge_ray), -1.0, 1.0))
	for angle in [-half_fov, half_fov]:
		draw_line(centre, centre + Vector2(sin(angle), -cos(angle)) * SCOPE_RADIUS, FAINT)
