extends DeckWeaponHUD
class_name CounterBatteryHUD

# The counter battery's slot line, plus a small blinking red dot on every
# threat it has marked until its missile is away.

const DOT_RADIUS: float = 3.0
const DOT_BLINK_RATE: float = 6.0
const DOT_COLOUR := Color(1.0, 0.18, 0.12, 0.95)
const DOT_FAINT := Color(1.0, 0.18, 0.12, 0.35)

var _clock: float = 0.0


func _update_hud(delta: float) -> void:
	_clock += delta


func _draw() -> void:
	super()
	if get_tree().paused:
		return
	var battery := weapon as CounterBattery
	var lit := fmod(_clock * DOT_BLINK_RATE, 1.0) < 0.5
	for marked: Variant in battery.marked:
		if not is_instance_valid(marked):
			continue
		var at := (marked as AbstractEnemy).global_position
		if turret.camera.is_position_behind(at):
			continue
		draw_circle(_project_world(turret.camera, at), DOT_RADIUS, DOT_COLOUR if lit else DOT_FAINT)
