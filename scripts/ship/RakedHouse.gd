@tool
extends MeshInstance3D
class_name RakedHouse

const MIN_SPAN := 0.001
const MIN_CORNERS := 3

@export var outline := PackedVector2Array():
	set(value):
		outline = value
		_rebuild()
@export var height: float = 4.0:
	set(value):
		height = value
		_rebuild()
@export var lean: float = 0.0:
	set(value):
		lean = value
		_rebuild()
@export var rake: float = 0.0:
	set(value):
		rake = value
		_rebuild()
@export var material: Material:
	set(value):
		material = value
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree() or outline.size() < MIN_CORNERS:
		return
	var roof := _roof_outline()
	var house := SurfaceTool.new()
	house.begin(Mesh.PRIMITIVE_TRIANGLES)
	house.set_smooth_group(-1)
	for index in outline.size():
		var next := (index + 1) % outline.size()
		var low_a := Vector3(outline[index].x, 0.0, outline[index].y)
		var low_b := Vector3(outline[next].x, 0.0, outline[next].y)
		var top_a := Vector3(roof[index].x, height, roof[index].y)
		var top_b := Vector3(roof[next].x, height, roof[next].y)
		for corner in [low_a, top_a, top_b, low_a, top_b, low_b]:
			house.add_vertex(corner)
	for corner in Geometry2D.triangulate_polygon(roof):
		house.add_vertex(Vector3(roof[corner].x, height, roof[corner].y))
	house.generate_normals()
	house.set_material(material)
	mesh = house.commit()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _roof_outline() -> PackedVector2Array:
	var centre := Vector2.ZERO
	var front := INF
	var back := -INF
	for point in outline:
		centre += point / outline.size()
		front = minf(front, point.y)
		back = maxf(back, point.y)
	var roof := PackedVector2Array()
	for index in outline.size():
		var point := outline[index]
		var before := _inward(outline[index - 1], point, centre)
		var after := _inward(point, outline[(index + 1) % outline.size()], centre)
		var shift := (before + after) * lean / (1.0 + before.dot(after))
		var share := clampf((back - point.y) / maxf(back - front, MIN_SPAN), 0.0, 1.0)
		roof.append(point + shift + Vector2(0.0, rake * share))
	return roof


func _inward(from: Vector2, to: Vector2, centre: Vector2) -> Vector2:
	var normal := (to - from).orthogonal().normalized()
	if normal.dot(centre - (from + to) * 0.5) < 0.0:
		normal = -normal
	return normal
