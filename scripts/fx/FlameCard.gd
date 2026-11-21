extends MeshInstance3D
class_name FlameCard

# One flame on a card that always turns to face the camera (the turning is
# done in its shader), so it never shows an edge from any side.

const STRENGTH_PARAMETER := &"strength"
const COLUMN_PARAMETER := &"column"


func _init(flame_mesh: Mesh) -> void:
	mesh = flame_mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The card turns in its shader, so its bounds must allow any facing.
	extra_cull_margin = 1.0


func _ready() -> void:
	set_instance_shader_parameter(COLUMN_PARAMETER, randf())


func resize(width: float, height: float) -> void:
	scale = Vector3(width, height, width)


func set_strength(value: float) -> void:
	set_instance_shader_parameter(STRENGTH_PARAMETER, value)
