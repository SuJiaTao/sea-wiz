extends MeshInstance3D
class_name VaporTrail

const ONSET_G: float = 3.5
const FULL_G: float = 6.5
const LIFETIME: float = 0.6
const WIDTH: float = 0.2
const VAPOUR := Color(0.4, 0.4, 0.4, 0.14)

@export var aircraft: FlyingEnemy

var _points: Array[Vector3] = []
var _ages: Array[float] = []
var _strengths: Array[float] = []
var _ribbon := ImmediateMesh.new()
var _tip: Node3D


func _ready() -> void:
	_tip = get_parent() as Node3D
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _ribbon
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint.vertex_color_use_as_albedo = true
	material_override = paint


func _process(delta: float) -> void:
	_age(delta)
	if is_instance_valid(aircraft) and aircraft.alive:
		var strength := clampf((aircraft.g_load - ONSET_G) / (FULL_G - ONSET_G), 0.0, 1.0)
		if strength > 0.0 or not _strengths.is_empty():
			_points.append(_tip.global_position)
			_ages.append(0.0)
			_strengths.append(strength)
	_rebuild()


func _age(delta: float) -> void:
	for index in _ages.size():
		_ages[index] += delta
	while not _ages.is_empty() and _ages[0] > LIFETIME:
		_points.pop_front()
		_ages.pop_front()
		_strengths.pop_front()


func _rebuild() -> void:
	_ribbon.clear_surfaces()
	var camera := get_viewport().get_camera_3d()
	if _points.size() < 2 or camera == null:
		return
	_ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index in _points.size():
		var point := _points[index]
		var along := _points[mini(index + 1, _points.size() - 1)] - _points[maxi(index - 1, 0)]
		var fresh := 1.0 - _ages[index] / LIFETIME
		var side := along.cross(camera.global_position - point).normalized() * WIDTH * (0.5 + fresh)
		var fade := _strengths[index] * fresh
		var colour := Color(VAPOUR, VAPOUR.a * fade)
		_ribbon.surface_set_color(colour)
		_ribbon.surface_add_vertex(point - side)
		_ribbon.surface_set_color(colour)
		_ribbon.surface_add_vertex(point + side)
	_ribbon.surface_end()
