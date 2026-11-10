extends MeshInstance3D
class_name RakedHouse
## A deckhouse built from its floor plan: walls rise from the outline and
## lean back toward the stern by `rake` metres at the roof, so faced and
## chamfered fronts slope the way a warship's superstructure does.

@export var outline := PackedVector2Array()
@export var height: float = 4.0
@export var rake: float = 0.0
@export var material: Material


func _ready() -> void:
	var house := SurfaceTool.new()
	house.begin(Mesh.PRIMITIVE_TRIANGLES)
	var front := _front_z()
	var back := _back_z()
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		var low_a := Vector3(a.x, 0.0, a.y)
		var low_b := Vector3(b.x, 0.0, b.y)
		var top_a := _roof(a, front, back)
		var top_b := _roof(b, front, back)
		for corner in [low_a, top_a, top_b, low_a, top_b, low_b]:
			house.add_vertex(corner)
	var roof := PackedVector2Array()
	for point in outline:
		var lifted := _roof(point, front, back)
		roof.append(Vector2(lifted.x, lifted.z))
	for corner in Geometry2D.triangulate_polygon(roof):
		house.add_vertex(Vector3(roof[corner].x, height, roof[corner].y))
	house.generate_normals()
	house.set_material(material)
	mesh = house.commit()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _roof(point: Vector2, front: float, back: float) -> Vector3:
	var share := clampf((back - point.y) / maxf(back - front, 0.001), 0.0, 1.0)
	return Vector3(point.x, height, point.y + rake * share)


func _front_z() -> float:
	var lowest := INF
	for point in outline:
		lowest = minf(lowest, point.y)
	return lowest


func _back_z() -> float:
	var highest := -INF
	for point in outline:
		highest = maxf(highest, point.y)
	return highest
