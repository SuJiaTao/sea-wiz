extends Node
## Autoload. Registers the input actions in code so the project never depends on
## a hand-edited InputMap. Everything is rebindable at runtime via InputMap.
##
## The mount is designed to be played entirely with the mouse. Keyboard
## bindings are kept as fallbacks, never as the only way to do something.

const ACTIONS := {
	"ciws_fire": [
		{"type": "mouse", "button": MOUSE_BUTTON_LEFT},
	],
	"ciws_zoom": [
		{"type": "mouse", "button": MOUSE_BUTTON_RIGHT},
		{"type": "key", "key": KEY_SHIFT},
	],
	"ciws_zoom_in": [
		{"type": "mouse", "button": MOUSE_BUTTON_WHEEL_UP},
	],
	"ciws_zoom_out": [
		{"type": "mouse", "button": MOUSE_BUTTON_WHEEL_DOWN},
	],
	"ciws_reload": [
		{"type": "mouse", "button": MOUSE_BUTTON_MIDDLE},
		{"type": "key", "key": KEY_R},
	],
	"ciws_polarity": [
		{"type": "key", "key": KEY_F},
	],
	# Hold while zoomed to build a seeker lock; it launches on the tone.
	"ciws_missile": [
		{"type": "mouse", "button": MOUSE_BUTTON_XBUTTON1},
		{"type": "key", "key": KEY_Q},
	],
	# The special: lock everything on screen and ripple-fire.
	"ciws_salvo": [
		{"type": "mouse", "button": MOUSE_BUTTON_XBUTTON2},
		{"type": "key", "key": KEY_E},
	],
	"ciws_pause": [
		{"type": "key", "key": KEY_ESCAPE},
	],
	"ciws_restart": [
		{"type": "mouse", "button": MOUSE_BUTTON_LEFT},
		{"type": "key", "key": KEY_ENTER},
		{"type": "key", "key": KEY_KP_ENTER},
	],
	"ciws_slew_left": [
		{"type": "key", "key": KEY_A},
		{"type": "key", "key": KEY_LEFT},
	],
	"ciws_slew_right": [
		{"type": "key", "key": KEY_D},
		{"type": "key", "key": KEY_RIGHT},
	],
	"ciws_slew_up": [
		{"type": "key", "key": KEY_W},
		{"type": "key", "key": KEY_UP},
	],
	"ciws_slew_down": [
		{"type": "key", "key": KEY_S},
		{"type": "key", "key": KEY_DOWN},
	],
}


func _enter_tree() -> void:
	for action_name in ACTIONS.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name, 0.2)
		for binding in ACTIONS[action_name]:
			var ev: InputEvent = _make_event(binding)
			if ev != null and not InputMap.action_has_event(action_name, ev):
				InputMap.action_add_event(action_name, ev)


func _make_event(binding: Dictionary) -> InputEvent:
	match binding.get("type", ""):
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = binding["key"]
			return k
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = binding["button"]
			return m
	return null
