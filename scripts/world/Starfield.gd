extends Node3D
class_name Starfield

# The night sky's stars as one multimesh: a scatter over the whole sky plus a
# denser drift of faint ones along the Milky Way, whose glow the sky paints.
# Most stars are faint, as in the real sky; zooming in brings more of them out.

const POLE := "milky_way_pole"
const MARKED := 1.0

@export var star_mesh: Mesh
@export var environment: WorldEnvironment
@export var count: int = 900
@export var band_count: int = 1500
@export var radius: float = 5500.0
@export var min_elevation_deg: float = 2.0
@export var brightness := Vector2(0.03, 0.6)
@export var band_brightness := Vector2(0.02, 0.32)
@export var faintness: float = 4.0
@export var size_pixels := Vector2(0.9, 1.3)
@export var band_bearing_deg: float = 45.0
@export var band_tilt_deg: float = 70.0
@export var band_spread: float = 0.12
@export var core_bearing_deg: float = 225.0
@export var core_share: float = 0.5
@export var layout_seed: int = 7

var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.seed = layout_seed
	var pole := _pole()
	if environment != null:
		(environment.environment.sky.sky_material as ShaderMaterial).set_shader_parameter(POLE, pole)
	var points: Array[Vector3] = []
	while points.size() < count:
		_keep(points, _random_direction())
	var along := _horizontal(band_bearing_deg)
	var across := pole.cross(along)
	var core := _horizontal(core_bearing_deg)
	while points.size() < count + band_count:
		var angle := _random.randf() * TAU
		var on_band := along * cos(angle) + across * sin(angle)
		if on_band.dot(core) < 0.0 and _random.randf() < core_share:
			on_band = -on_band
		_keep(points, (on_band + pole * _random.randfn(0.0, band_spread)).normalized())
	_build(points)


func _keep(points: Array[Vector3], direction: Vector3) -> void:
	if direction.y > sin(deg_to_rad(min_elevation_deg)):
		points.append(direction)


func _build(points: Array[Vector3]) -> void:
	var stars := MultiMesh.new()
	stars.transform_format = MultiMesh.TRANSFORM_3D
	stars.use_custom_data = true
	stars.mesh = star_mesh
	stars.instance_count = points.size()
	for index in points.size():
		stars.set_instance_transform(index, Transform3D(Basis.IDENTITY, points[index] * radius))
		var range := brightness if index < count else band_brightness
		var shine := lerpf(range.x, range.y, pow(_random.randf(), faintness))
		var size := lerpf(size_pixels.x, size_pixels.y, shine)
		stars.set_instance_custom_data(index, Color(shine, size, _random.randf(), MARKED))
	var field := MultiMeshInstance3D.new()
	field.multimesh = stars
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	field.custom_aabb = AABB(Vector3.ONE * -radius, Vector3.ONE * radius * 2.0)
	add_child(field)


func _random_direction() -> Vector3:
	var bearing := _random.randf() * TAU
	var elevation := asin(_random.randf())
	return Vector3(sin(bearing) * cos(elevation), sin(elevation), -cos(bearing) * cos(elevation))


func _pole() -> Vector3:
	var tilt := deg_to_rad(band_tilt_deg)
	return (_horizontal(band_bearing_deg + 90.0) * sin(tilt) + Vector3.UP * cos(tilt)).normalized()


func _horizontal(bearing_deg: float) -> Vector3:
	var bearing := deg_to_rad(bearing_deg)
	return Vector3(sin(bearing), 0.0, -cos(bearing))
