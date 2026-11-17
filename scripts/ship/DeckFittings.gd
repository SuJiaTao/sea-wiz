extends Node3D
class_name DeckFittings

# Builds the deck furniture from the hull's own outline: edge railings, the
# forward missile cell block, the breakwater, bollards, anchor gear and the
# raised step in front of the deckhouse.

const RAIL_HEIGHT: float = 1.0
const RAIL_MID_SHARE: float = 0.5
const RAIL_INSET: float = 0.3
const RAIL_POST_SPACING: float = 2.0
const RAIL_THICKNESS: float = 0.05
const RAIL_AFT_LIMIT: float = 84.0
const RAIL_FORE_LIMIT: float = -75.0

const CELL_CENTER := Vector3(0.0, 0.0, -42.0)
const CELL_ROWS: int = 8
const CELL_COLUMNS: int = 8
const CELL_PITCH := Vector2(0.78, 1.1)
const CELL_LID_SHARE: float = 0.84
const CELL_BASE_HEIGHT: float = 0.25
const CELL_LID_HEIGHT: float = 0.06
const CELL_MARGIN: float = 0.35

const BREAKWATER_APEX_Z: float = -64.5
const BREAKWATER_END_Z: float = -61.5
const BREAKWATER_HALF_SPAN: float = 4.0
const BREAKWATER_HEIGHT: float = 1.1
const BREAKWATER_THICKNESS: float = 0.12

const STEP_FRONT_Z: float = -9.0
const STEP_BACK_Z: float = 1.0
const STEP_HALF_WIDTH: float = 6.4
const STEP_HEIGHT: float = 1.4

const BOLLARD_STATIONS: Array[float] = [-56.0, -24.0, 22.0, 52.0, 76.0]
const BOLLARD_OUTBOARD_GAP: float = 1.1
const BOLLARD_RADIUS: float = 0.18
const BOLLARD_HEIGHT: float = 0.5
const BOLLARD_PAIR_GAP: float = 0.6

const WINDLASS := Vector2(2.0, -65.5)
const HAWSE := Vector2(1.6, -73.0)
const WINDLASS_RADIUS: float = 0.4
const WINDLASS_LENGTH: float = 0.7
const CHAIN_LINK_LENGTH: float = 0.32
const CHAIN_LINK_SIZE := Vector2(0.14, 0.06)

const CYLINDER_SEGMENTS: int = 10

@export var hull: HullMesh
@export var fitting_material: Material
@export var hatch_material: Material

var _fittings := SurfaceTool.new()
var _hatches := SurfaceTool.new()
var _box := BoxMesh.new()
var _cylinder := CylinderMesh.new()


func _ready() -> void:
	_box.size = Vector3.ONE
	_cylinder.top_radius = 0.5
	_cylinder.bottom_radius = 0.5
	_cylinder.height = 1.0
	_cylinder.radial_segments = CYLINDER_SEGMENTS
	_cylinder.rings = 1
	for tool in [_fittings, _hatches]:
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		_add_railing(side)
		_add_bollards(side)
		_add_anchor_gear(side)
		_add_breakwater_wing(side)
	_add_cell_block()
	_add_step()
	_commit(_fittings, fitting_material, "Fittings")
	_commit(_hatches, hatch_material, "Hatches")


func _deck(x: float, z: float) -> Vector3:
	return Vector3(x, hull.deck_level(z), z)


func _add_railing(side: float) -> void:
	var previous := Vector3.INF
	var z := RAIL_AFT_LIMIT
	while z >= RAIL_FORE_LIMIT:
		var half := hull.half_breadth_at(z)
		if not is_nan(half) and half > RAIL_INSET * 2.0:
			var foot := _deck(side * (half - RAIL_INSET), z)
			_beam(foot, foot + Vector3.UP * RAIL_HEIGHT, RAIL_THICKNESS)
			if previous != Vector3.INF:
				for share in [RAIL_MID_SHARE, 1.0]:
					var lift: Vector3 = Vector3.UP * RAIL_HEIGHT * share
					_beam(previous + lift, foot + lift, RAIL_THICKNESS)
			previous = foot
		z -= RAIL_POST_SPACING


func _add_bollards(side: float) -> void:
	for z in BOLLARD_STATIONS:
		var x := side * (hull.half_breadth_at(z) - BOLLARD_OUTBOARD_GAP)
		for offset in [-0.5, 0.5]:
			var foot: Vector3 = _deck(x, z + offset * BOLLARD_PAIR_GAP)
			_post(foot, BOLLARD_RADIUS, BOLLARD_HEIGHT)


func _add_anchor_gear(side: float) -> void:
	var drum := _deck(side * WINDLASS.x, WINDLASS.y) + Vector3.UP * WINDLASS_RADIUS
	var axis := Vector3.RIGHT * WINDLASS_LENGTH * 0.5
	_drum(drum - axis, drum + axis, WINDLASS_RADIUS)
	var start := _deck(side * WINDLASS.x, WINDLASS.y)
	var finish := _deck(side * HAWSE.x, HAWSE.y)
	var links := int(start.distance_to(finish) / CHAIN_LINK_LENGTH)
	for index in links:
		var a := start.lerp(finish, float(index) / links)
		var b := start.lerp(finish, float(index + 1) / links)
		var lift := Vector3.UP * CHAIN_LINK_SIZE.y
		var flat := index % 2 == 0
		_block(a + lift, b + lift, CHAIN_LINK_SIZE.x if flat else CHAIN_LINK_SIZE.y,
				CHAIN_LINK_SIZE.y if flat else CHAIN_LINK_SIZE.x, _fittings)


func _add_breakwater_wing(side: float) -> void:
	var apex := _deck(0.0, BREAKWATER_APEX_Z)
	var end := _deck(side * BREAKWATER_HALF_SPAN, BREAKWATER_END_Z)
	var rise := Vector3.UP * BREAKWATER_HEIGHT * 0.5
	_block(apex + rise, end + rise, BREAKWATER_THICKNESS, BREAKWATER_HEIGHT, _fittings)


func _add_cell_block() -> void:
	var base := _deck(CELL_CENTER.x, CELL_CENTER.z)
	var span := Vector2(CELL_COLUMNS * CELL_PITCH.x, CELL_ROWS * CELL_PITCH.y) + Vector2.ONE * CELL_MARGIN * 2.0
	_place(_box, Transform3D(
		Basis.from_scale(Vector3(span.x, CELL_BASE_HEIGHT, span.y)),
		base + Vector3.UP * CELL_BASE_HEIGHT * 0.5), _hatches)
	var lid := Vector3(CELL_PITCH.x * CELL_LID_SHARE, CELL_LID_HEIGHT, CELL_PITCH.y * CELL_LID_SHARE)
	for row in CELL_ROWS:
		for column in CELL_COLUMNS:
			var at := base + Vector3(
				(column - (CELL_COLUMNS - 1) * 0.5) * CELL_PITCH.x,
				CELL_BASE_HEIGHT + CELL_LID_HEIGHT * 0.5,
				(row - (CELL_ROWS - 1) * 0.5) * CELL_PITCH.y)
			_place(_box, Transform3D(Basis.from_scale(lid), at), _fittings)


func _add_step() -> void:
	var length := STEP_BACK_Z - STEP_FRONT_Z
	var center := _deck(0.0, (STEP_FRONT_Z + STEP_BACK_Z) * 0.5) + Vector3.UP * STEP_HEIGHT * 0.5
	_place(_box, Transform3D(Basis.from_scale(Vector3(STEP_HALF_WIDTH * 2.0, STEP_HEIGHT, length)), center), _fittings)


func _beam(a: Vector3, b: Vector3, thickness: float) -> void:
	_block(a, b, thickness, thickness, _fittings)


func _block(a: Vector3, b: Vector3, width: float, height: float, tool: SurfaceTool) -> void:
	var along := b - a
	var forward := along.normalized()
	var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.99 else Vector3.BACK
	var right := up.cross(forward).normalized()
	up = forward.cross(right)
	var basis := Basis(right * width, up * height, forward * along.length())
	_place(_box, Transform3D(basis, (a + b) * 0.5), tool)


func _post(foot: Vector3, radius: float, height: float) -> void:
	var basis := Basis.from_scale(Vector3(radius * 2.0, height, radius * 2.0))
	_place(_cylinder, Transform3D(basis, foot + Vector3.UP * height * 0.5), _fittings)


func _drum(a: Vector3, b: Vector3, radius: float) -> void:
	var basis := Basis(Vector3.UP * radius * 2.0, (b - a), Vector3.FORWARD * radius * 2.0)
	_place(_cylinder, Transform3D(basis, (a + b) * 0.5), _fittings)


func _place(shape: PrimitiveMesh, placement: Transform3D, tool: SurfaceTool) -> void:
	tool.append_from(shape, 0, placement)


func _commit(tool: SurfaceTool, material: Material, part_name: String) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = tool.commit()
	part.material_override = material
	add_child(part)
