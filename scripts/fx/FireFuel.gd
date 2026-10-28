extends RefCounted
class_name FireFuel

const LOOP_RADIUS: float = 1.5
const HOT_SPOT_LOW: float = 0.4
const HOT_SPOT_HIGH: float = 0.6

var row := PackedByteArray()

var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _floor: float
var _flicker_speed: float


func _init(width: int, hot_spot_frequency: float, floor_heat: float, flicker_speed: float) -> void:
	row.resize(width)
	_noise.seed = randi()
	_noise.frequency = hot_spot_frequency
	_floor = floor_heat
	_flicker_speed = flicker_speed


func advance(delta: float) -> void:
	_time += delta * _flicker_speed
	var width := row.size()
	for x in width:
		var angle := TAU * float(x) / float(width)
		var burn := _noise.get_noise_3d(
			cos(angle) * LOOP_RADIUS, sin(angle) * LOOP_RADIUS, _time
		) * 0.5 + 0.5
		var heat := lerpf(_floor, 1.0, smoothstep(HOT_SPOT_LOW, HOT_SPOT_HIGH, burn))
		row[x] = int(DoomFire.MAX_HEAT * heat)
