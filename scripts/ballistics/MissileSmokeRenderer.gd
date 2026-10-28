extends ParticleBatch
class_name MissileSmokeRenderer

const PUFF_SPACING: float = 2.0
const NOZZLE_OFFSET: float = 1.2
const EXHAUST_SPEED := Vector2(2.0, 7.0)
const EXHAUST_SCATTER: float = 1.2
const BOOST_PUFF_SCALE: float = 1.6
const BOOST_LIFE_SCALE: float = 0.45
const LAUNCH_SOUND_PATH := "res://audio/missile_launch.wav"
const LAUNCH_VOLUME_DB: float = -1.0
const LAUNCH_PITCH := Vector2(0.92, 1.08)
const AUDIO_VOICES: int = 6
const AUDIO_UNIT_SIZE: float = 180.0
const AUDIO_MAX_DISTANCE: float = 4000.0

var _launch_sound: AudioStream
var _audio_pool: Array[AudioStreamPlayer3D] = []
var _audio_index: int = 0


func _ready() -> void:
	super()
	if ResourceLoader.exists(LAUNCH_SOUND_PATH):
		_launch_sound = load(LAUNCH_SOUND_PATH)
	for index in AUDIO_VOICES:
		var player := AudioStreamPlayer3D.new()
		player.unit_size = AUDIO_UNIT_SIZE
		player.max_distance = AUDIO_MAX_DISTANCE
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player)
		_audio_pool.append(player)


func emit_trail(from_position: Vector3, to_position: Vector3, boosting: bool) -> void:
	var travel := to_position - from_position
	var distance := travel.length()
	if distance <= 0.0:
		return
	var backward := -travel / distance
	var puffs := int(distance / PUFF_SPACING + randf())
	var size_scale := BOOST_PUFF_SCALE if boosting else 1.0
	var life_scale := BOOST_LIFE_SCALE if boosting else 1.0
	for index in puffs:
		var along := (float(index) + randf()) / float(puffs)
		var exhaust := (
			backward * randf_range(EXHAUST_SPEED.x, EXHAUST_SPEED.y)
			+ random_direction() * EXHAUST_SCATTER
		)
		emit(from_position + travel * along + backward * NOZZLE_OFFSET, exhaust, size_scale, life_scale)


func play_launch(at: Vector3) -> void:
	if _launch_sound == null or _audio_pool.is_empty():
		return
	var player := _audio_pool[_audio_index]
	_audio_index = (_audio_index + 1) % _audio_pool.size()
	player.global_position = at
	player.stream = _launch_sound
	player.volume_db = LAUNCH_VOLUME_DB
	player.pitch_scale = randf_range(LAUNCH_PITCH.x, LAUNCH_PITCH.y)
	player.play()
