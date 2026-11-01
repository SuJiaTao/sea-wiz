extends MeshInstance3D
class_name HullMesh

@export var half_breadths := PackedVector2Array()
@export var deck_height: float = 6.0
@export var bow_sheer: float = 2.0
@export var sheer_start: float = -15.0
@export var keel_depth: float = -4.0
@export_range(0.1, 1.0) var waterline_tuck: float = 0.85
@export var side_material: Material
@export var deck_material: Material


func _ready() -> void:
	var hull := ArrayMesh.new()
	_add_sides(hull)
	_add_deck(hull)
	mesh = hull
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func deck_level(z: float) -> float:
	var bow := half_breadths[half_breadths.size() - 1].x
	var rise := clampf((z - sheer_start) / (bow - sheer_start), 0.0, 1.0)
	return deck_height + bow_sheer * rise * rise


func _outline() -> PackedVector2Array:
	var outline := PackedVector2Array()
	for station in half_breadths:
		outline.append(Vector2(station.y, station.x))
	for index in range(half_breadths.size() - 1, -1, -1):
		var station := half_breadths[index]
		if station.y > 0.0:
			outline.append(Vector2(-station.y, station.x))
	return outline


func _add_sides(hull: ArrayMesh) -> void:
	var sides := SurfaceTool.new()
	sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline := _outline()
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		var top_a := Vector3(a.x, deck_level(a.y), a.y)
		var top_b := Vector3(b.x, deck_level(b.y), b.y)
		var low_a := Vector3(a.x * waterline_tuck, keel_depth, a.y)
		var low_b := Vector3(b.x * waterline_tuck, keel_depth, b.y)
		for corner in [top_a, top_b, low_b, top_a, low_b, low_a]:
			sides.add_vertex(corner)
	sides.generate_normals()
	sides.set_material(side_material)
	sides.commit(hull)


func _add_deck(hull: ArrayMesh) -> void:
	var deck := SurfaceTool.new()
	deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline := _outline()
	for corner in Geometry2D.triangulate_polygon(outline):
		var point := outline[corner]
		deck.add_vertex(Vector3(point.x, deck_level(point.y), point.y))
	deck.generate_normals()
	deck.set_material(deck_material)
	deck.commit(hull)
