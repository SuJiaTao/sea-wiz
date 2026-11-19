extends Node3D
class_name FlameCard

# A flame built from sheets that cross at its centre, so it never looks like a
# flat card from any side.

const STRENGTH_PARAMETER := &"strength"
const COLUMN_PARAMETER := &"column"
const SHEETS: int = 3

var _sheets: Array[MeshInstance3D] = []


func _init(flame_mesh: Mesh) -> void:
	rotation.y = randf() * TAU
	for index in SHEETS:
		var sheet := MeshInstance3D.new()
		sheet.mesh = flame_mesh
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sheet.rotation.y = PI * index / SHEETS
		add_child(sheet)
		_sheets.append(sheet)


func _ready() -> void:
	for sheet in _sheets:
		sheet.set_instance_shader_parameter(COLUMN_PARAMETER, randf())


func resize(width: float, height: float) -> void:
	scale = Vector3(width, height, width)


func set_strength(value: float) -> void:
	for sheet in _sheets:
		sheet.set_instance_shader_parameter(STRENGTH_PARAMETER, value)
