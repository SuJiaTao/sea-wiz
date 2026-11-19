extends Node
class_name PowerGrid

# Ship's power. In a blackout wave it fails a few seconds in: the picture
# starves to the brightest flashes, the HUD and radar go dark, and only the
# etched backup cross and your ears are left. It comes back as the next
# wave is announced.

signal lost()
signal restored()

const CUT_DELAY: float = 5.0
const FLICKER_TIME: float = 1.4
const FLICKER_RATE: float = 14.0
const RESTORE_DELAY: float = 1.5
const MESSAGE_TIME: float = 5.0
const RESTORED_MESSAGE := "POWER RESTORED  /  DECK WEAPONS ONLINE"
const SPIN_DOWN := Vector2(180.0, 30.0)
const SPIN_UP := Vector2(40.0, 260.0)
const SPIN_TIME: float = 1.6

@export var waves: WaveOrchestrator
@export var hud: GameplayHUD
@export var video: AnalogVideo
@export var radar: SearchRadar
@export var reticle: BackupReticle
@export var hum: AudioStreamPlayer

var out: bool = false

var _cut_in: float = -1.0
var _restore_in: float = -1.0
var _flicker: float = 0.0
var _message_left: float = 0.0


func _ready() -> void:
	waves.level_started.connect(_on_level_started)
	waves.level_prepared.connect(_on_level_prepared)
	reticle.hide()


func _on_level_started(_number: int, _title: String) -> void:
	if waves.current_level.blackout and not out:
		_cut_in = CUT_DELAY


func _on_level_prepared(_number: int, _title: String) -> void:
	if out and not waves.current_level.blackout:
		_restore_in = RESTORE_DELAY


func _process(delta: float) -> void:
	_cut_in = _count_down(_cut_in, delta, _cut)
	_restore_in = _count_down(_restore_in, delta, _restore)
	if _flicker > 0.0:
		_flicker = maxf(_flicker - delta, 0.0)
		var lit := sin(_flicker * FLICKER_RATE * TAU) > 0.0
		var dark := out if _flicker <= 0.0 else not lit
		video.set_blackout(1.0 if dark else 0.0)
		hud.visible = not dark
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0 and hud.message == RESTORED_MESSAGE:
			hud.message = ""


func _count_down(clock: float, delta: float, action: Callable) -> float:
	if clock < 0.0:
		return clock
	clock -= delta
	if clock < 0.0:
		action.call()
	return clock


func _cut() -> void:
	out = true
	_flicker = FLICKER_TIME
	radar.set_physics_process(false)
	reticle.show()
	_play(SPIN_DOWN)
	lost.emit()


func _restore() -> void:
	out = false
	_flicker = FLICKER_TIME
	radar.set_physics_process(true)
	reticle.hide()
	hud.message = RESTORED_MESSAGE
	_message_left = MESSAGE_TIME
	_play(SPIN_UP)
	restored.emit()


func _play(sweep: Vector2) -> void:
	hum.stream = ToneSweep.make(sweep.x, sweep.y, SPIN_TIME)
	hum.play()
