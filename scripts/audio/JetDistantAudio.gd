extends Node3D
class_name JetDistantAudio

# The far-off roar of each jet in earshot: a seamless loop that rides along
# with the jet, panning with it, muffling and fading with distance, and
# falling silent past hearing range, where a jet is only something you see.
# When a jet's close pass recording takes over it fades out of here, and it
# fades back in once that recording is done.

## Beyond this a jet is seen, not heard.
const HEARING_RANGE: float = 3200.0
## The last stretch before hearing range where the roar fades to nothing.
const FADE_BAND: float = 900.0
## Distance at which the loop plays at full level.
const UNIT_SIZE: float = 160.0
const LOOP_DB: float = -6.0
const SILENT_DB: float = -80.0
## Each jet's loop starts somewhere different and at a slightly different
## pitch, so several jets never phase into one tone.
const PITCH_SPREAD: float = 0.06
## Far-off sound loses its highs.
const MUFFLE_CUTOFF_HZ: float = 2500.0
const MUFFLE_DB: float = -18.0

@export var enemies: EnemyManager
@export var listener: Node3D
@export var flybys: JetFlybyAudio
@export var loop: AudioStream
@export var bus: StringName = &"Master"

var _loops: Dictionary[AbstractEnemy, AudioStreamPlayer3D] = {}


func _ready() -> void:
	if loop is AudioStreamOggVorbis:
		(loop as AudioStreamOggVorbis).loop = true


func _process(_delta: float) -> void:
	var ear := listener.global_position
	for enemy in enemies.live_enemies():
		var jet := enemy as FlyingEnemy
		if jet == null or not jet.jet_engine:
			continue
		var distance := jet.global_position.distance_to(ear)
		var player: AudioStreamPlayer3D = _loops.get(jet)
		if distance > HEARING_RANGE:
			if player != null:
				_stop(jet)
			continue
		if player == null:
			player = _start(jet)
		player.global_position = jet.global_position
		var reach := clampf((HEARING_RANGE - distance) / FADE_BAND, 0.0, 1.0)
		var level := reach * (flybys.far_share(jet) if flybys != null else 1.0)
		player.volume_db = LOOP_DB + linear_to_db(maxf(level, db_to_linear(SILENT_DB)))
	_tidy()


func _start(jet: AbstractEnemy) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = loop
	player.bus = bus
	player.unit_size = UNIT_SIZE
	player.max_distance = HEARING_RANGE
	player.attenuation_filter_cutoff_hz = MUFFLE_CUTOFF_HZ
	player.attenuation_filter_db = MUFFLE_DB
	player.pitch_scale = 1.0 + randf_range(-PITCH_SPREAD, PITCH_SPREAD)
	player.volume_db = SILENT_DB
	add_child(player)
	player.global_position = jet.global_position
	player.play(randf() * loop.get_length())
	_loops[jet] = player
	return player


## A jet that is shot down or gone takes its roar with it.
func _tidy() -> void:
	for enemy: Variant in _loops.keys():
		if not is_instance_valid(enemy) or not (enemy as AbstractEnemy).alive:
			_stop(enemy)


func _stop(enemy: Variant) -> void:
	var player: AudioStreamPlayer3D = _loops[enemy]
	_loops.erase(enemy)
	player.queue_free()
