extends AudioStreamPlayer
class_name ShipFireAudio

# The roar and crackle of fire on board: a seamless loop that swells in as a
# fire takes, grows with the worst blaze on deck, and dies away once the
# fires are out.

## Level with a small fire, and with the whole ship burning.
const SMALL_FIRE_DB: float = -14.0
const FULL_FIRE_DB: float = -2.0
const SILENT_DB: float = -60.0
## How fast the sound follows the fire, in decibels per second.
const SWELL_RATE: float = 30.0
const FADE_RATE: float = 10.0

@export var fires: DeckFires

var _level_db: float = SILENT_DB


func _ready() -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	volume_db = SILENT_DB


func _process(delta: float) -> void:
	var blaze := fires.blaze()
	var wanted := lerpf(SMALL_FIRE_DB, FULL_FIRE_DB, blaze) if blaze > 0.0 else SILENT_DB
	var rate := SWELL_RATE if wanted > _level_db else FADE_RATE
	_level_db = move_toward(_level_db, wanted, rate * delta)
	volume_db = _level_db
	if _level_db > SILENT_DB and not playing:
		play(randf() * stream.get_length())
	elif _level_db <= SILENT_DB and playing:
		stop()
