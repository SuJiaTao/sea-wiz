extends Node3D
class_name ShipModel

# The imported destroyer model, repainted with the ship's own night paint so it
# takes the moonlight and shadows. Painted deck markings stay visible, and the
# bridge windows give off a faint glow of their own so they read as windows.

const DEFAULT_TONE: float = 0.3
const MARKED_MATERIAL := "Deck_Painted"
const MARKINGS_BASE: float = 0.07
const WINDOW_MATERIAL := "Bridge_Glass"
const GLOW_PARAMETER := &"glow"

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
	"Bridge_Glass": 0.09,
	"Radome_White": 0.62,
}
## Tint of the light behind the bridge glass.
@export var window_color := Color(0.7, 0.9, 1.0)
## How strongly the bridge windows glow. Tune this if they read too bright or
## too dim through the night vision.
@export var window_glow: float = 0.055

var _paints: Dictionary = {}


func _ready() -> void:
	var built := model.instantiate()
	add_child(built)
	for part in built.find_children("*", "MeshInstance3D", true, false):
		var mesh := part as MeshInstance3D
		var lit_window := false
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.mesh.surface_get_material(surface)
			mesh.set_surface_override_material(surface, _paint_for(original))
			lit_window = lit_window or (original != null and original.resource_name == WINDOW_MATERIAL)
		if lit_window:
			mesh.set_instance_shader_parameter(GLOW_PARAMETER, window_glow)


func _paint_for(original: Material) -> ShaderMaterial:
	var material_name := original.resource_name if original != null else ""
	if not _paints.has(material_name):
		var coat := ShaderMaterial.new()
		coat.shader = paint
		coat.set_shader_parameter("tone", tones.get(material_name, DEFAULT_TONE))
		if material_name == MARKED_MATERIAL and original is BaseMaterial3D:
			coat.set_shader_parameter("markings", (original as BaseMaterial3D).albedo_texture)
			coat.set_shader_parameter("markings_base", MARKINGS_BASE)
		if material_name == WINDOW_MATERIAL:
			coat.set_shader_parameter("glow_color", window_color)
		_paints[material_name] = coat
	return _paints[material_name]
