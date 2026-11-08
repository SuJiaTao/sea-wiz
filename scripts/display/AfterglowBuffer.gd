extends SubViewport
class_name AfterglowBuffer

const AFTERGLOW_SHADER := preload("res://shaders/afterglow.gdshader")

@export var source: SubViewport
@export_range(0.0, 0.99) var decay: float = 0.7


func _ready() -> void:
	render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var frame := TextureRect.new()
	frame.texture = source.get_texture()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	var glow := ShaderMaterial.new()
	glow.shader = AFTERGLOW_SHADER
	glow.set_shader_parameter("decay", decay)
	frame.material = glow
	add_child(frame)
