extends Node
class_name TrackManager

const SEARCH_ALPHA := 0.5
const SEARCH_BETA := 0.3

@export var search_radar: SearchRadar
@export var tentative_lifetime: float = 1.2
@export var confirmed_lifetime: float = 2.2

var _tracks: Array[RadarTrack] = []
var _next_id: int = 1


func _ready() -> void:
	search_radar.detected.connect(_on_detected)
	search_radar.enemies.enemy_killed.connect(_on_enemy_killed)


func tracks() -> Array[RadarTrack]:
	return _tracks


func has_track(track: RadarTrack) -> bool:
	return _tracks.has(track)


func _physics_process(delta: float) -> void:
	for track in _tracks:
		track.coast(delta)
	_tracks = _tracks.filter(_still_held)


func _still_held(track: RadarTrack) -> bool:
	if track.lost():
		return false
	var lifetime := confirmed_lifetime if track.confirmed else tentative_lifetime
	return track.since_update <= lifetime


func _on_detected(detection: RadarDetection) -> void:
	var track := _track_of(detection.source)
	if track == null:
		_tracks.append(RadarTrack.new(_next_id, detection))
		_next_id += 1
		return
	track.correct(detection.position, detection.error, SEARCH_ALPHA, SEARCH_BETA)


func _on_enemy_killed(enemy: AbstractEnemy, _source: DamageSource) -> void:
	_tracks = _tracks.filter(func(track: RadarTrack) -> bool: return not track.follows(enemy))


func _track_of(enemy: AbstractEnemy) -> RadarTrack:
	for track in _tracks:
		if track.follows(enemy):
			return track
	return null
