extends RefCounted
class_name CursorManager

static var _capture_mouse : int = 0


## Increments _capture_mouse by 1, mouse is capture while is_mouse_captured == true [br]
## If val == false, decrements instead.[br]
static func capture_mouse(val:bool=true) -> void:
	_capture_mouse += 1 if val else -1
	_update()


## Decrements _capture_mouse by 1, mouse is capture while is_mouse_captured == true.[br]
static func free_mouse() -> void:
	_capture_mouse -= 1
	_update()



static func is_mouse_captured() -> bool:
	return _capture_mouse > 0


static func _update() -> void:
	if is_mouse_captured():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE