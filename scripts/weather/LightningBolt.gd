extends MeshInstance3D
class_name LightningBolt

const DETAIL_LEVELS: int = 6
const JAGGEDNESS: float = 0.18
const BRANCHES: int = 2
const BRANCH_LENGTH: float = 0.35
const BRANCH_SPREAD: float = 0.5
const FLASHES := Vector2i(2, 4)
const FLASH_ON: float = 0.06
const FLASH_GAP: float = 0.05

var _pattern: Array[bool] = []
var _clock: float = 0.0


func strike(top: Vector3, ground: Vector3) -> void:
	var points := _jagged(top, ground)
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	_add_path(lines, points)
	for branch in BRANCHES:
		var from: Vector3 = points[randi_range(points.size() / 4, points.size() / 2)]
		var away := (ground - top).length() * BRANCH_LENGTH
		var tip := from + (Vector3(randf_range(-1.0, 1.0), -1.0, randf_range(-1.0, 1.0)) * Vector3(BRANCH_SPREAD, 1.0, BRANCH_SPREAD)).normalized() * away
		_add_path(lines, _jagged(from, tip))
	lines.surface_end()
	mesh = lines
	_pattern.clear()
	for flash in randi_range(FLASHES.x, FLASHES.y):
		_pattern.append(true)
		_pattern.append(false)
	_clock = 0.0
	visible = true


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	var step := int(_clock / (FLASH_ON + FLASH_GAP) * 2.0)
	if step >= _pattern.size():
		visible = false
		return
	transparency = 0.0 if _pattern[step] else 1.0


func _jagged(from: Vector3, to: Vector3) -> PackedVector3Array:
	var points := PackedVector3Array([from, to])
	var offset := from.distance_to(to) * JAGGEDNESS
	for level in DETAIL_LEVELS:
		var finer := PackedVector3Array()
		for index in points.size() - 1:
			var a := points[index]
			var b := points[index + 1]
			finer.append(a)
			finer.append((a + b) * 0.5 + Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 0.3), randf_range(-1.0, 1.0)) * offset)
		finer.append(points[points.size() - 1])
		points = finer
		offset *= 0.5
	return points


func _add_path(lines: ImmediateMesh, points: PackedVector3Array) -> void:
	for index in points.size() - 1:
		lines.surface_add_vertex(points[index])
		lines.surface_add_vertex(points[index + 1])
