extends MeshInstance3D
class_name FlameCard

const STRENGTH_PARAMETER := &"strength"
const COLUMN_PARAMETER := &"column"


func _init(flame_mesh: Mesh) -> void:
	mesh = flame_mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _ready() -> void:
	set_instance_shader_parameter(COLUMN_PARAMETER, randf())


func resize(width: float, height: float) -> void:
	scale = Vector3(width, height, 1.0)


func set_strength(value: float) -> void:
	set_instance_shader_parameter(STRENGTH_PARAMETER, value)
