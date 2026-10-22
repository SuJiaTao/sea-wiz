extends TextureRect
class_name SensorAfterimage

const HALF := 0.5

@export var source: SubViewport
@export var trail_half_life: float = 0.18

@onready var _buffer: SubViewport = get_parent() as SubViewport
@onready var _feedback: ShaderMaterial = material as ShaderMaterial


func _ready() -> void:
	texture = source.get_texture()


func _process(delta: float) -> void:
	_buffer.size = source.size
	size = Vector2(source.size)
	_feedback.set_shader_parameter("retention", _retention(delta))


func _retention(delta: float) -> float:
	if trail_half_life <= 0.0:
		return 0.0
	return pow(HALF, delta / trail_half_life)
