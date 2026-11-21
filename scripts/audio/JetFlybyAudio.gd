extends Node3D
class_name JetFlybyAudio

# Recorded flybys for jets that pass close. Each jet's track is worked out
# ahead: when it is set to pass near us, a recording starts timed so its
# loudest moment lands as the jet goes by, and follows the jet through the
# sky so it pans with it. Passes overhead get the overhead recording, the
# rest the one that roars in from behind. While a recording plays, that jet
# fades out of the distant rumble, so the two hand over without a gap.

## Passes that come no closer than this stay part of the distant rumble.
const PASS_DISTANCE: float = 700.0
## A pass at least this steep above us counts as overhead.
const OVERHEAD_ELEVATION_DEG: float = 50.0
## Too slow or too far ahead to predict a pass.
const MIN_CLOSING_SPEED: float = 20.0
## How long the rumble takes to hand a jet over to its recording, and back.
const HANDOVER_TIME: float = 1.5
## A jet must fall back this far before it can get another recording.
const REARM_DISTANCE: float = 1500.0
const LOUDEST_DB: float = 0.0
## How much quieter a pass at the edge of PASS_DISTANCE is than a direct one.
const GRAZE_DROP_DB: float = 9.0

@export var enemies: EnemyManager
@export var listener: Node3D
@export var overhead: FlybySound
@export var behind: FlybySound
@export var bus: StringName = &"Master"

var _flybys: Dictionary[AbstractEnemy, AudioStreamPlayer3D] = {}
var _handed_over: Dictionary[AbstractEnemy, float] = {}


## How much of this jet should still be heard in the distant rumble, 0 to 1.
func far_share(enemy: AbstractEnemy) -> float:
	return 1.0 - _handed_over.get(enemy, 0.0)


func _process(delta: float) -> void:
	var ear := listener.global_position
	for enemy in enemies.live_enemies():
		var jet := enemy as FlyingEnemy
		if jet == null or not jet.jet_engine:
			continue
		_follow(jet, ear, delta)
	_tidy(delta)


func _follow(jet: FlyingEnemy, ear: Vector3, delta: float) -> void:
	var player: AudioStreamPlayer3D = _flybys.get(jet)
	if player == null:
		_maybe_start(jet, ear)
		return
	player.global_position = jet.global_position
	var step := delta / HANDOVER_TIME
	var share: float = _handed_over.get(jet, 0.0)
	# Back to the rumble once the recording is over; a new pass needs the jet
	# to fall well back first.
	share = clampf(share + (step if player.playing else -step), 0.0, 1.0)
	_handed_over[jet] = share
	if not player.playing and share <= 0.0 and jet.global_position.distance_to(ear) > REARM_DISTANCE:
		_release(jet)


func _maybe_start(jet: FlyingEnemy, ear: Vector3) -> void:
	var offset := jet.global_position - ear
	var speed_squared := jet.velocity.length_squared()
	if speed_squared < MIN_CLOSING_SPEED * MIN_CLOSING_SPEED:
		return
	var until_closest := -offset.dot(jet.velocity) / speed_squared
	if until_closest <= 0.0:
		return
	var closest := offset + jet.velocity * until_closest
	var miss := closest.length()
	if miss > PASS_DISTANCE:
		return
	var elevation := rad_to_deg(asin(clampf(closest.y / maxf(miss, 1.0), -1.0, 1.0)))
	var sound := overhead if elevation >= OVERHEAD_ELEVATION_DEG else behind
	if until_closest > sound.closest_at:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = sound.stream
	player.bus = bus
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	player.volume_db = LOUDEST_DB - GRAZE_DROP_DB * miss / PASS_DISTANCE
	add_child(player)
	player.global_position = jet.global_position
	player.play(sound.closest_at - until_closest)
	_flybys[jet] = player
	_handed_over[jet] = 0.0


## A recording outlives its jet: a shot-down jet's roar still trails off.
func _tidy(delta: float) -> void:
	for enemy: Variant in _flybys.keys():
		if is_instance_valid(enemy) and (enemy as AbstractEnemy).alive:
			continue
		var player: AudioStreamPlayer3D = _flybys[enemy]
		_flybys.erase(enemy)
		_handed_over.erase(enemy)
		if player.playing:
			player.finished.connect(player.queue_free)
		else:
			player.queue_free()


func _release(jet: AbstractEnemy) -> void:
	var player: AudioStreamPlayer3D = _flybys[jet]
	_flybys.erase(jet)
	_handed_over.erase(jet)
	player.queue_free()
