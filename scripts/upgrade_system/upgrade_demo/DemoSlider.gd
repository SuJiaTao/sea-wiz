extends HSlider

@export var value_label : Label


func _ready() -> void:
	value_changed.connect(update)


func update(val: float) -> void:
	value_label.text = str(val as int)
