extends Node3D
class_name WaterBlastAudio

# The sound of a blast on the sea: a roar and the crash of the water column
# falling back. It reaches us late, at the speed of sound, comes from where
# the blast was, and is quieter the further off it went up. Close blasts use
# the close recording; further out the far recording takes over, blending
# between the two in the middle.

const SOUND_SPEED: float = 343.0
## Up to here only the close recording plays.
const CLOSE_RANGE: float = 500.0
## From here on only the far recording plays.
const FAR_RANGE: float = 1500.0
const HEARING_RANGE: float = 4000.0
## Distance at which a blast plays at full level.
const UNIT_SIZE: float = 220.0
const PITCH_SPREAD: float = 0.07
const SILENT_DB: float = -80.0
const VOICES: int = 6

@export var effects: EffectManager
@export var listener: Node3D
@export var close: AudioStream
@export var far: AudioStream
@export var bus: StringName = &"Master"

var _voices: Array[AudioStreamPlayer3D] = []
var _next: int = 0


func _ready() -> void:
	for index in VOICES * 2:
		var player := AudioStreamPlayer3D.new()
		player.bus = bus
		player.unit_size = UNIT_SIZE
		player.max_distance = HEARING_RANGE
		add_child(player)
		_voices.append(player)
	effects.shockwave.connect(_on_shockwave)


func _on_shockwave(at: Vector3, _size: float, on_water: bool) -> void:
	if not on_water:
		return
	var distance := at.distance_to(listener.global_position)
	if distance > HEARING_RANGE:
		return
	get_tree().create_timer(distance / SOUND_SPEED, false).timeout.connect(_play.bind(at, distance))


func _play(at: Vector3, distance: float) -> void:
	var farness := 0.0 if far == null else smoothstep(CLOSE_RANGE, FAR_RANGE, distance)
	var pitch := 1.0 + randf_range(-PITCH_SPREAD, PITCH_SPREAD)
	_voice(close, at, 1.0 - farness, pitch)
	_voice(far, at, farness, pitch)


func _voice(stream: AudioStream, at: Vector3, share: float, pitch: float) -> void:
	if stream == null or share <= 0.0:
		return
	var player := _voices[_next]
	_next = (_next + 1) % _voices.size()
	player.stream = stream
	player.global_position = at
	player.pitch_scale = pitch
	# Equal-power blend, so the handover between recordings holds its level.
	player.volume_db = maxf(linear_to_db(sqrt(share)), SILENT_DB)
	player.play()
