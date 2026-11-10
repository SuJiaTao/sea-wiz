extends Node
class_name LaserHUD

const GLOW_SHADER := preload("res://shaders/hud_glow.gdshader")

@export var hud_root: Control
@export var layer: CanvasLayer

var _projector: SubViewport
var _glass: TextureRect


func _ready() -> void:
	_project.call_deferred()


func _project() -> void:
	_projector = SubViewport.new()
	_projector.transparent_bg = true
	_projector.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_projector.size = get_viewport().get_visible_rect().size
	layer.add_child(_projector)
	hud_root.reparent(_projector, false)
	_glass = TextureRect.new()
	_glass.texture = _projector.get_texture()
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glass.set_anchors_preset(Control.PRESET_FULL_RECT)
	var glow := ShaderMaterial.new()
	glow.shader = GLOW_SHADER
	_glass.material = glow
	layer.add_child(_glass)
	layer.move_child(_glass, 0)
	get_viewport().size_changed.connect(_fit)


func glass_material() -> ShaderMaterial:
	return _glass.material as ShaderMaterial if _glass != null else null


func _fit() -> void:
	_projector.size = get_viewport().get_visible_rect().size
