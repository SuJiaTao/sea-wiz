extends Node3D
class_name ShipHitAudio

# Cannon rounds striking the ship: each strike is the clang of metal with a
# ricochet whining off it, the ricochet pitched a little differently every
# time. Now and then a round only glances off, and only the ricochet plays.
# Strikes closer together than a short gap merge into one, so a burst
# rattles instead of turning into a wall of noise.

## A round only glances off this share of the time.
const GLANCE_CHANCE: float = 0.12
const RICOCHET_PITCH := Vector2(0.85, 1.15)
const HIT_PITCH := Vector2(0.95, 1.05)
## Strikes closer together than this are heard as one.
const MIN_GAP: float = 0.08
const RICOCHET_DB: float = -4.0
const VOICES: int = 8

@export var enemies: EnemyManager
@export var hit: AudioStream
@export var ricochet: AudioStream
@export var bus: StringName = &"Master"

var _voices: Array[AudioStreamPlayer3D] = []
var _next: int = 0
var _quiet_for: float = 0.0


func _ready() -> void:
	for index in VOICES:
		var player := AudioStreamPlayer3D.new()
		player.bus = bus
		add_child(player)
		_voices.append(player)
	enemies.enemy_created.connect(_on_enemy_created)


func _process(delta: float) -> void:
	_quiet_for = maxf(_quiet_for - delta, 0.0)


func _on_enemy_created(enemy: AbstractEnemy) -> void:
	if enemy is StrikeAircraft:
		(enemy as StrikeAircraft).round_struck.connect(_on_round_struck)


func _on_round_struck(at: Vector3) -> void:
	if _quiet_for > 0.0:
		return
	_quiet_for = MIN_GAP
	if randf() >= GLANCE_CHANCE:
		_voice(hit, at, randf_range(HIT_PITCH.x, HIT_PITCH.y), 0.0)
	_voice(ricochet, at, randf_range(RICOCHET_PITCH.x, RICOCHET_PITCH.y), RICOCHET_DB)


func _voice(stream: AudioStream, at: Vector3, pitch: float, level_db: float) -> void:
	var player := _voices[_next]
	_next = (_next + 1) % _voices.size()
	player.stream = stream
	player.global_position = at
	player.pitch_scale = pitch
	player.volume_db = level_db
	player.play()
