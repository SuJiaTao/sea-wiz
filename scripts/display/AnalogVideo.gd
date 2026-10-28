extends ColorRect
class_name AnalogVideo

@export var palettes: Array[PhosphorPalette] = []

var palette: PhosphorPalette:
	get:
		return palettes[_palette_index] if not palettes.is_empty() else null

var _palette_index: int = 0

@onready var _signal: ShaderMaterial = material as ShaderMaterial


func _ready() -> void:
	_apply_palette()


func next_palette() -> void:
	if palettes.is_empty():
		return
	_palette_index = (_palette_index + 1) % palettes.size()
	_apply_palette()


func _apply_palette() -> void:
	if palette == null:
		return
	_signal.set_shader_parameter("phosphor", palette.phosphor)
	_signal.set_shader_parameter("highlight_bleach", palette.highlight_bleach)
