extends Node3D
class_name DestroyerBridge

# The imported bridge, mast and deckhouse model, repainted with the ship's own
# night paint so it takes the moonlight and shadows like the hull does.

const DEFAULT_TONE: float = 0.3

@export var model: PackedScene
@export var paint: Shader
@export var tones: Dictionary = {
	"Hull_Grey": 0.34,
	"Deck_Grey": 0.27,
	"Seam_Grey": 0.3,
	"SPY_Panel": 0.31,
	"Mast_Dark": 0.2,
	"Window_Dark": 0.06,
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
			var name := original.resource_name if original != null else ""
			mesh.set_surface_override_material(surface, _paint_for(name))


func _paint_for(material_name: String) -> ShaderMaterial:
	if not _paints.has(material_name):
		var coat := ShaderMaterial.new()
		coat.shader = paint
		coat.set_shader_parameter("tone", tones.get(material_name, DEFAULT_TONE))
		_paints[material_name] = coat
	return _paints[material_name]
