extends Resource
class_name PhosphorPalette

@export var display_name: String = ""
@export var phosphor: Color = Color.WHITE
@export_range(0.0, 1.0) var highlight_bleach: float = 0.0
@export var shadow: Color = Color.BLACK
@export var midtone: Color = Color(0.5, 0.5, 0.5)
@export_range(0.05, 0.95) var mid_point: float = 0.5
