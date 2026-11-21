extends AudioStreamPlayer
class_name ShipGroan

# While the ship is on fire its hull groans: the recording plays every so
# often, sooner and louder the worse the blaze, each time at a slightly
# different pitch so it never sounds like the same clip twice.

## The first groan comes this soon after the fire takes.
const FIRST_DELAY := Vector2(0.4, 1.2)
## Gap between groans with a small fire, and with the whole ship burning.
const SMALL_FIRE_GAP := Vector2(9.0, 15.0)
const FULL_FIRE_GAP := Vector2(3.5, 7.0)
const PITCH_RANGE := Vector2(0.82, 1.06)
## Level with a small fire, and with the whole ship burning.
const SMALL_FIRE_DB: float = -12.0
const FULL_FIRE_DB: float = 0.0

@export var fires: DeckFires

var _wait: float = 0.0
var _alight: bool = false


func _process(delta: float) -> void:
	var blaze := fires.blaze()
	if blaze <= 0.0:
		_alight = false
		return
	if not _alight:
		_alight = true
		_wait = randf_range(FIRST_DELAY.x, FIRST_DELAY.y)
	_wait -= delta
	if _wait > 0.0 or playing:
		return
	pitch_scale = randf_range(PITCH_RANGE.x, PITCH_RANGE.y)
	volume_db = lerpf(SMALL_FIRE_DB, FULL_FIRE_DB, blaze)
	play()
	var gap := SMALL_FIRE_GAP.lerp(FULL_FIRE_GAP, blaze)
	_wait = stream.get_length() / pitch_scale + randf_range(gap.x, gap.y)
