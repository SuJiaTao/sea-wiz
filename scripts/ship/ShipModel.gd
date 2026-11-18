extends Node3D
class_name ShipModel

# The imported destroyer model, repainted with the ship's own night paint so it
# takes the moonlight and shadows. Painted deck markings stay visible, and the
# laser lenses get their own coat so each can glow on its own.

const DEFAULT_TONE: float = 0.3
const MARKED_MATERIAL := "Deck_Painted"
const MARKINGS_BASE: float = 0.07
const LENS_MATERIAL := "Lens_Glass"
const LENS_GLOW_COLOR := Color(1.0, 0.95, 0.85)

@export var model: PackedScene
@export var paint: Shader
@export var tones: Dictionary = {
	"Hull_Grey": 0.34,
	"Hull_Grey_2S": 0.34,
	"Deck_Grey": 0.27,
	"Deck_Painted": 0.3,
	"Seam_Grey": 0.3,
	"SPY_Panel": 0.31,
	"Mast_Dark": 0.2,
	"Window_Dark": 0.06,
	"Lens_Glass": 0.05,
	"Radome_White": 0.62,
}

var _paints: Dictionary = {}


func _ready() -> void:
	var built := model.instantiate()
	add_child(built)
	for part in built.find_children("*", "MeshInstance3D", true, false):
		var mesh := part as MeshInstance3D
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.mesh.surface_get_material(surface)
			mesh.set_surface_override_material(surface, _paint_for(original))


func _paint_for(original: Material) -> ShaderMaterial:
	var material_name := original.resource_name if original != null else ""
	if not _paints.has(material_name):
		var coat := ShaderMaterial.new()
		coat.shader = paint
		coat.set_shader_parameter("tone", tones.get(material_name, DEFAULT_TONE))
		if material_name == MARKED_MATERIAL and original is BaseMaterial3D:
			coat.set_shader_parameter("markings", (original as BaseMaterial3D).albedo_texture)
			coat.set_shader_parameter("markings_base", MARKINGS_BASE)
		if material_name == LENS_MATERIAL:
			coat.set_shader_parameter("glow_color", LENS_GLOW_COLOR)
		_paints[material_name] = coat
	return _paints[material_name]
