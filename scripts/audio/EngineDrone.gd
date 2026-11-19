extends AudioStreamPlayer
class_name EngineDrone

# The roar of everything flying near us, mixed into one rumble that pans
# toward where the engines are and swells as they close. With the power out
# it is how you find them.

const MIX_RATE: float = 22050.0
const BUFFER_SECONDS: float = 0.12
const HEARING_RANGE: float = 3500.0
const NEAR_RANGE: float = 200.0
const RUMBLE_SMOOTHING: float = 0.06
const RUMBLE_GAIN: float = 3.0
const HISS_GAIN: float = 0.08
const GAIN_GLIDE: float = 0.002
const MAX_GAIN: float = 1.0

@export var enemies: EnemyManager
@export var turret: Turret

var _playback: AudioStreamGeneratorPlayback
var _rumble: float = 0.0
var _left: float = 0.0
var _right: float = 0.0


func _ready() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = BUFFER_SECONDS
	stream = generator
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var wanted := _loudness()
	for frame in _playback.get_frames_available():
		var white := randf() * 2.0 - 1.0
		_rumble = lerpf(_rumble, white, RUMBLE_SMOOTHING)
		var sample := _rumble * RUMBLE_GAIN + white * HISS_GAIN
		_left = move_toward(_left, wanted.x, GAIN_GLIDE)
		_right = move_toward(_right, wanted.y, GAIN_GLIDE)
		_playback.push_frame(Vector2(sample * _left, sample * _right))


## Left and right loudness summed over every engine in earshot.
func _loudness() -> Vector2:
	if get_tree().paused:
		return Vector2.ZERO
	var camera := turret.camera
	var total := Vector2.ZERO
	for enemy in enemies.live_enemies():
		if not enemy is FlyingEnemy:
			continue
		var offset := enemy.global_position - camera.global_position
		var distance := offset.length()
		var near := clampf((HEARING_RANGE - distance) / (HEARING_RANGE - NEAR_RANGE), 0.0, 1.0)
		if near <= 0.0:
			continue
		var loud := near * near
		var side := camera.global_basis.x.dot(offset / distance)
		total += Vector2(sqrt((1.0 - side) * 0.5), sqrt((1.0 + side) * 0.5)) * loud
	return total.clampf(0.0, MAX_GAIN)
