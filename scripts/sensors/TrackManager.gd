extends Node
class_name TrackManager

const GATE_SIGMAS := 3.0
const SEARCH_ALPHA := 0.5
const SEARCH_BETA := 0.3

@export var search_radar: SearchRadar
@export var tentative_lifetime: float = 1.5
@export var confirmed_lifetime: float = 3.2

var _tracks: Array[RadarTrack] = []
var _next_id: int = 1


func _ready() -> void:
	search_radar.detected.connect(_on_detected)


func tracks() -> Array[RadarTrack]:
	return _tracks


func has_track(track: RadarTrack) -> bool:
	return _tracks.has(track)


func _physics_process(delta: float) -> void:
	for track in _tracks:
		track.coast(delta)
	_tracks = _tracks.filter(_still_held)


func _still_held(track: RadarTrack) -> bool:
	var lifetime := confirmed_lifetime if track.confirmed else tentative_lifetime
	return track.since_update <= lifetime


func _on_detected(detection: RadarDetection) -> void:
	var track := _associate(detection)
	if track == null:
		_tracks.append(RadarTrack.new(_next_id, detection))
		_next_id += 1
		return
	track.correct(detection.position, detection.error, SEARCH_ALPHA, SEARCH_BETA)
	track.size_hint = lerpf(track.size_hint, detection.size_hint, SEARCH_ALPHA)


func _associate(detection: RadarDetection) -> RadarTrack:
	var best: RadarTrack
	var best_distance := INF
	for track in _tracks:
		var gate := track.uncertainty + GATE_SIGMAS * detection.error
		var distance := track.position.distance_to(detection.position)
		if distance < gate and distance < best_distance:
			best = track
			best_distance = distance
	return best
