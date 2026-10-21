extends HUDPanel
class_name GameplayHUD

var message: String = ""

@onready var player: PlayerHUD = $PlayerHUD


func set_health(current: float, maximum: float) -> void:
	player.set_health(current, maximum)


func _draw() -> void:
	if not message.is_empty():
		_center(size.y * 0.5 + 60, message, 22)
