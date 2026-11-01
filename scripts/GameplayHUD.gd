extends HUDPanel
class_name GameplayHUD

var message: String = ""

func _draw() -> void:
	if not message.is_empty():
		_center(size.y * 0.5 + 60, message, 22)
