extends HUDPanel
class_name WeatherHUD

const LINE := Vector2(28, 210)
const LABEL_SIZE: int = 12
const SHOWN_FROM: float = 0.05

@export var weather: WeatherDirector


func _draw() -> void:
	if weather.strength < SHOWN_FROM:
		return
	_text(LINE, "WX  " + weather.profile.display_name, LABEL_SIZE, Color(DIM, DIM.a * weather.strength))
