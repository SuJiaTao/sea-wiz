extends HUDPanel
class_name TrackHUD

const RADAR_RANGE: float = 4000.0
const SCOPE_RADIUS: float = 96.0
const SCOPE_MARGIN: float = 34.0
const SCOPE_TICKS: int = 12
const SCOPE_TICK_LENGTH: float = 6.0
const CLOUD_MIN_METRES: float = 260.0
const CLOUD_MIN_PIXELS: float = 7.0
const CLOUD_PUFFS: int = 5
const CLOUD_SPREAD: float = 0.55
const CLOUD_ALPHA: float = 0.16
const MARKED_DOT: float = 2.5
const MARKER_SIZE: float = 7.0
const MARKER_LIFT: float = 14.0
const EDGE_MARGIN: float = 28.0
const EDGE_ARROW: float = 9.0
const PING_TIME: float = 0.6
const PING_RADIUS: float = 40.0
const GATE_MIN: float = 10.0
const GATE_MAX: float = 70.0
const GATE_OPEN: float = 2.2
const GATE_CORNER: float = 0.45
const SPOT_RING: float = 16.0
const SPOT_RING_SEGMENTS: int = 24

@export var turret: Turret
@export var tracks: TrackManager
@export var spotter: Spotter
@export var gun_director: GunDirector

var _pings: Dictionary = {}


func _ready() -> void:
	spotter.marked.connect(_on_marked)


func _update_hud(delta: float) -> void:
	for enemy: Variant in _pings.keys():
		_pings[enemy] += delta
		if _pings[enemy] > PING_TIME or not is_instance_valid(enemy):
			_pings.erase(enemy)


func _draw() -> void:
	for enemy in spotter.marked_enemies():
		_draw_marker(enemy)
	_draw_spotting()
	_draw_gate()
	_draw_scope()


func _on_marked(enemy: AbstractEnemy) -> void:
	_pings[enemy] = 0.0


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
		_draw_edge_arrow(enemy.global_position)
		return
	var point := _project(enemy.global_position)
	var top := point - Vector2(0, _screen_radius(enemy) + MARKER_LIFT)
	draw_colored_polygon(PackedVector2Array([
		top + Vector2(-MARKER_SIZE, -MARKER_SIZE),
		top + Vector2(MARKER_SIZE, -MARKER_SIZE),
		top
	]), DIM)
	if _pings.has(enemy) and _pings[enemy] < PING_TIME:
		var age: float = _pings[enemy] / PING_TIME
		draw_arc(point, PING_RADIUS * age, 0, TAU, 32, Color(MAIN, 1.0 - age), 1.5)


func _draw_edge_arrow(world_position: Vector3) -> void:
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
	]), DIM)


func _draw_spotting() -> void:
	var enemy := spotter.candidate
	if not is_instance_valid(enemy) or not _on_screen(enemy.global_position):
		return
	var point := _project(enemy.global_position)
	var radius := maxf(_screen_radius(enemy), SPOT_RING)
	var start := -PI * 0.5
	draw_arc(point, radius, start, start + TAU * spotter.progress, SPOT_RING_SEGMENTS, MAIN, 1.5)


func _draw_gate() -> void:
	var enemy := gun_director.target
	if not is_instance_valid(enemy) or not _on_screen(enemy.global_position):
		return
	var convergence := gun_director.convergence
	var point := _project(enemy.global_position)
	var half := clampf(_screen_radius(enemy) * 1.3, GATE_MIN, GATE_MAX)
	half *= lerpf(GATE_OPEN, 1.0, convergence)
	var corner := half * GATE_CORNER
	var colour := MAIN if convergence >= 1.0 else DIM
	var width := 2.0 if convergence >= 1.0 else 1.0
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var at := point + Vector2(sx, sy) * half
			draw_line(at, at - Vector2(sx * corner, 0), colour, width)
			draw_line(at, at - Vector2(0, sy * corner), colour, width)


func _draw_scope() -> void:
	var centre := Vector2(size.x - SCOPE_RADIUS - SCOPE_MARGIN, size.y - SCOPE_RADIUS - SCOPE_MARGIN)
	draw_arc(centre, SCOPE_RADIUS, 0, TAU, 64, DIM)
	for fraction in [0.33, 0.66]:
		draw_arc(centre, SCOPE_RADIUS * fraction, 0, TAU, 48, FAINT)
	for i in SCOPE_TICKS:
		var tick := TAU * float(i) / float(SCOPE_TICKS)
		var direction := Vector2(sin(tick), -cos(tick))
		draw_line(centre + direction * (SCOPE_RADIUS - SCOPE_TICK_LENGTH), centre + direction * SCOPE_RADIUS, FAINT)
	draw_circle(centre, 2.5, MAIN)
	_draw_field_of_view(centre)

	var marked := spotter.marked_enemies()
	for track in tracks.tracks():
		if not _belongs_to_marked(track, marked):
			_draw_cloud(centre, track)
	for enemy in marked:
		draw_circle(_scope_point(centre, enemy.global_position), MARKED_DOT, MAIN)

	_text(
		centre + Vector2(-SCOPE_RADIUS, SCOPE_RADIUS + 18),
		"HEAT  %.1f km   MARKED %d" % [RADAR_RANGE / 1000.0, marked.size()], 11, FAINT
	)


func _scope_point(centre: Vector2, world_position: Vector3) -> Vector2:
	var offset := world_position - turret.global_position
	var distance := Vector2(offset.x, offset.z).length()
	var angle := wrapf(atan2(offset.x, -offset.z) - deg_to_rad(turret.bearing_deg()), -PI, PI)
	var reach := clampf(distance / RADAR_RANGE, 0.0, 1.0) * SCOPE_RADIUS
	return centre + Vector2(sin(angle), -cos(angle)) * reach


func _belongs_to_marked(track: RadarTrack, marked: Array[AbstractEnemy]) -> bool:
	for enemy in marked:
		if enemy.global_position.distance_to(track.position) < track.uncertainty + CLOUD_MIN_METRES:
			return true
	return false


func _draw_cloud(centre: Vector2, track: RadarTrack) -> void:
	var metres := maxf(track.uncertainty, CLOUD_MIN_METRES)
	var radius := maxf(metres / RADAR_RANGE * SCOPE_RADIUS, CLOUD_MIN_PIXELS)
	var point := _scope_point(centre, track.position)
	var scatter := RandomNumberGenerator.new()
	scatter.seed = track.id
	for i in CLOUD_PUFFS:
		var drift := Vector2(scatter.randf_range(-1, 1), scatter.randf_range(-1, 1)) * radius * CLOUD_SPREAD
		var puff := radius * scatter.randf_range(0.5, 1.0)
		draw_circle(point + drift, puff, Color(DIM, CLOUD_ALPHA))


func _draw_field_of_view(centre: Vector2) -> void:
	var camera := turret.camera
	var viewport_size := Vector2(camera.get_viewport().get_visible_rect().size)
	var edge_ray := camera.project_ray_normal(Vector2(0, viewport_size.y * 0.5))
	var half_fov := acos(clampf((-camera.global_basis.z).dot(edge_ray), -1.0, 1.0))
	for angle in [-half_fov, half_fov]:
		draw_line(centre, centre + Vector2(sin(angle), -cos(angle)) * SCOPE_RADIUS, FAINT)
