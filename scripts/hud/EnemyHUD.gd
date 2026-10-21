extends HUDPanel
class_name EnemyHUD

const RADAR_RANGE: float = 2400.0
const TRACK_CONE_DEG: float = 30.0

@export var enemies: EnemyManager
@export var turret: Turret

var _contacts: Array[AbstractEnemy] = []
var _tracked: AbstractEnemy


func _update_hud(_delta: float) -> void:
	_contacts = enemies.live_enemies()
	_tracked = _select_target(_contacts)


func _select_target(contacts: Array[AbstractEnemy]) -> AbstractEnemy:
	var camera := turret.camera
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	var best: AbstractEnemy
	var nearest: AbstractEnemy
	var best_score := -INF
	var nearest_distance := INF

	for enemy in contacts:
		var offset := enemy.global_position - origin
		var distance := offset.length()
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
		if distance < 1.0:
			continue
		var angle := rad_to_deg(acos(clampf(
			forward.dot(offset / distance), -1.0, 1.0
		)))
		if angle > TRACK_CONE_DEG:
			continue
		var score := -angle * 3.0 - distance * 0.004
		if score > best_score:
			best_score = score
			best = enemy

	return best if best != null else nearest


func _draw() -> void:
	_draw_contacts()
	if is_instance_valid(_tracked):
		_draw_lead()
	_draw_radar()


func _project(world_position: Vector3) -> Vector2:
	var camera := turret.camera
	var viewport_size := Vector2(camera.get_viewport().get_visible_rect().size)
	return camera.unproject_position(world_position) / viewport_size * size


func _on_screen(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point)


func _draw_contacts() -> void:
	var camera := turret.camera
	var shown := 0

	for enemy in _contacts:
		if not is_instance_valid(enemy):
			continue
		if camera.is_position_behind(enemy.global_position):
			continue
		var point := _project(enemy.global_position)
		if not _on_screen(point):
			continue
		var tracked := enemy == _tracked
		if shown >= 15 and not tracked:
			continue
		shown += 1

		var edge := _project(
			enemy.global_position + camera.global_basis.x * enemy.hud_radius
		)
		var half := clampf(point.distance_to(edge), 8.0, 90.0)
		var color := MAIN if tracked else DIM
		_draw_brackets(point, half, color, 2.0 if tracked else 1.0)

		var offset := enemy.global_position - turret.global_position
		var distance := offset.length()
		if tracked:
			var label := point + Vector2(half + 8, -half + 2)
			_text(label, enemy.display_name, 12)
			_text(label + Vector2(0, 15), "%d m" % int(distance), 12)
			var closure := -enemy.velocity.dot(offset.normalized())
			_text(
				label + Vector2(0, 30),
				"%+d m/s" % int(closure), 12
			)
			_bar(
				point + Vector2(-half, half + 6),
				Vector2(half * 2.0, 7),
				enemy.hp / maxf(enemy.max_hp, 1.0)
			)
		elif distance < 600.0:
			_text(
				point + Vector2(half + 5, 4),
				"%d" % int(distance), 10, FAINT
			)


func _draw_brackets(
	point: Vector2,
	half: float,
	color: Color,
	width: float
) -> void:
	var length := half * 0.35
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			var corner := point + Vector2(x, y) * half
			draw_line(corner, corner - Vector2(x * length, 0), color, width)
			draw_line(corner, corner - Vector2(0, y * length), color, width)


func _draw_lead() -> void:
	var time := _intercept_time(
		_tracked.global_position - turret.muzzle.global_position,
		_tracked.velocity,
		Turret.MUZZLE_VELOCITY
	)
	if time <= 0.0:
		return
	var aim := (
		_tracked.global_position + _tracked.velocity * time
		+ Vector3.UP * 0.5 * BulletProjectile.GRAVITY * time * time
	)
	if turret.camera.is_position_behind(aim):
		return
	var point := _project(aim)
	if not _on_screen(point):
		return

	draw_polyline(PackedVector2Array([
		point + Vector2(0, -9),
		point + Vector2(9, 0),
		point + Vector2(0, 9),
		point + Vector2(-9, 0),
		point + Vector2(0, -9)
	]), MAIN, 1.5)
	draw_line(size * 0.5, point, Color(0.9, 1, 0.9, 0.18))
	_text(point + Vector2(12, 16), "TOF %.2fs" % time, 11, DIM)


func _intercept_time(
	offset: Vector3,
	velocity: Vector3,
	speed: float
) -> float:
	var a := velocity.length_squared() - speed * speed
	var b := 2.0 * offset.dot(velocity)
	var c := offset.length_squared()
	if absf(a) < 0.0001:
		return -c / b if absf(b) >= 0.0001 else -1.0
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return -1.0
	var root := sqrt(discriminant)
	var first := (-b - root) / (2.0 * a)
	var second := (-b + root) / (2.0 * a)
	if first > 0.0 and second > 0.0:
		return minf(first, second)
	return maxf(first, second)


func _draw_radar() -> void:
	var radius := 96.0
	var center := Vector2(size.x - radius - 34, size.y - radius - 34)
	draw_arc(center, radius, 0, TAU, 64, DIM)
	for fraction in [0.33, 0.66]:
		draw_arc(center, radius * fraction, 0, TAU, 48, FAINT)
	for i in range(12):
		var angle := TAU * float(i) / 12.0
		var direction := Vector2(sin(angle), -cos(angle))
		draw_line(
			center + direction * (radius - 6),
			center + direction * radius, FAINT
		)
	draw_circle(center, 2.5, MAIN)

	var camera := turret.camera
	var viewport_size := Vector2(camera.get_viewport().get_visible_rect().size)
	var edge_ray := camera.project_ray_normal(Vector2(0, viewport_size.y * 0.5))
	var half_fov := acos(clampf(
		(-camera.global_basis.z).dot(edge_ray), -1.0, 1.0
	))
	for angle in [-half_fov, half_fov]:
		draw_line(
			center,
			center + Vector2(sin(angle), -cos(angle)) * radius,
			FAINT
		)

	var bearing := deg_to_rad(turret.bearing_deg())
	for enemy in _contacts:
		if not is_instance_valid(enemy):
			continue
		var offset := enemy.global_position - turret.global_position
		var distance := Vector2(offset.x, offset.z).length()
		var angle := wrapf(atan2(offset.x, -offset.z) - bearing, -PI, PI)
		var point := center + Vector2(sin(angle), -cos(angle)) * (
			clampf(distance / RADAR_RANGE, 0, 1) * radius
		)
		var color := MAIN if enemy == _tracked else DIM
		var half := 4.0 if enemy.hud_radius > 12.0 else 2.5
		draw_rect(
			Rect2(point - Vector2(half, half), Vector2.ONE * half * 2),
			color, enemy == _tracked
		)

	_text(
		center + Vector2(-radius, radius + 18),
		"SURVEILLANCE  %.1f km" % (RADAR_RANGE / 1000.0), 11, FAINT
	)
