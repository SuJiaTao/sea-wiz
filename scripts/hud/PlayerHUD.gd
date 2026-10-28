extends HUDPanel
class_name PlayerHUD

@export var turret: Turret
@export var thermal: ThermalView
@export var video: AnalogVideo

var _phase: float = 0.0


func _update_hud(delta: float) -> void:
	_phase += delta


func _draw() -> void:
	_draw_reticle()
	_draw_compass()
	_draw_gauges()
	_draw_view_info()


func _draw_reticle() -> void:
	var center := size * 0.5
	for direction in [
		Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN
	]:
		draw_line(
			center + direction * 8.0,
			center + direction * 26.0,
			MAIN, 1.5
		)
	draw_circle(center, 1.5, MAIN)

	var camera := turret.camera
	var distance := camera.near + 1.0
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	var right := camera.global_basis.x
	var spread := tan(deg_to_rad(turret.dispersion_deg * 2.5))
	var viewport_size := Vector2(camera.get_viewport().get_visible_rect().size)
	var a := camera.unproject_position(origin + forward * distance)
	var b := camera.unproject_position(
		origin + forward * distance + right * spread * distance
	)
	var radius := absf(b.x - a.x) * size.x / viewport_size.x
	draw_arc(center, maxf(radius, 4.0), 0, TAU, 40, FAINT)

	if turret.firing:
		var color := Color(1, 1, 1, 0.35 + 0.25 * sin(_phase * 60.0))
		draw_arc(center, 34, 0, TAU, 40, color)


func _draw_compass() -> void:
	var bearing := turret.bearing_deg()
	var half_width := size.x * 0.26
	var center_x := size.x * 0.5
	var y := 34.0
	var span := 70.0

	draw_line(
		Vector2(center_x - half_width, y),
		Vector2(center_x + half_width, y), FAINT
	)

	var first := int(floor((bearing - span * 0.5) / 5.0)) * 5
	for i in range(16):
		var degrees := float(first + i * 5)
		var offset := wrapf(degrees - bearing, -180.0, 180.0)
		if absf(offset) > span * 0.5:
			continue
		var x := center_x + offset / span * half_width * 2.0
		var major := int(fposmod(degrees, 30.0)) == 0
		draw_line(
			Vector2(x, y),
			Vector2(x, y + (10.0 if major else 5.0)), DIM
		)
		if major:
			_text(
				Vector2(x - 14, y + 26),
				"%03d" % int(fposmod(degrees, 360.0)), 12, DIM
			)

	draw_polyline(PackedVector2Array([
		Vector2(center_x - 6, y - 9),
		Vector2(center_x, y - 1),
		Vector2(center_x + 6, y - 9)
	]), MAIN, 2.0)
	_center(y - 14, "%03d" % int(bearing), 14)
	_text(
		Vector2(center_x + half_width + 12, y + 5),
		"EL %+03d" % int(turret.elevation_deg()), 12, DIM
	)


func _draw_gauges() -> void:
	var origin := Vector2(28, size.y - 154)
	var ammo_fraction := float(turret.ammo) / float(Turret.MAGAZINE)
	var warning := Color(1, 1, 1, 0.65 + 0.35 * sin(_phase * 8.0))

	_text(origin + Vector2(0, 44), "MAGAZINE", 12, DIM)
	_bar(
		origin + Vector2(0, 52), Vector2(190, 12), ammo_fraction,
		warning if ammo_fraction < 0.15 else MAIN
	)
	_text(
		origin + Vector2(198, 62),
		"%d / %d" % [turret.ammo, Turret.MAGAZINE], 12
	)

	if turret.reloading:
		_text(origin + Vector2(0, 96), "RELOADING", 16, warning)
	elif turret.spin > 0.05:
		_text(
			origin + Vector2(0, 96),
			"BARRELS %d%%" % int(turret.spin * 100.0), 14, DIM
		)


func _draw_view_info() -> void:
	var origin := Vector2(size.x - 290, 82)
	var polarity := "BLACK HOT" if thermal.polarity > 0.5 else "WHITE HOT"
	var fov := turret.camera.fov
	_text(origin, "MODE  " + polarity + "   " + video.palette.display_name, 12, DIM)
	_text(
		origin + Vector2(0, 20),
		"ZOOM %.1fx   FOV %.0f" % [
			TurretCamera.FOV_WIDE / maxf(fov, 1.0), fov	
		], 12, DIM
	)
	_text(origin + Vector2(0, 48), "MOUSE / WASD  AIM", 11, FAINT)
	_text(origin + Vector2(0, 64), "LEFT  GUN    RIGHT / SHIFT  ZOOM", 11, FAINT)
	_text(origin + Vector2(0, 80), "WHEEL  ZOOM    MIDDLE / R  RELOAD", 11, FAINT)
	_text(origin + Vector2(0, 96), "F  POLARITY    C  COLOUR    ESC  PAUSE", 11, FAINT)
