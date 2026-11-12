extends RefCounted
class_name LensDroplet

const JIGGLE_RATE: float = 26.0
const JIGGLE_SETTLE: float = 6.0
const JIGGLE_SIZE: float = 0.35
const SAG_TIME: float = 0.18
const SAG_DISTANCE: float = 0.6
const STRETCH_PER_SPEED: float = 0.12
const MAX_STRETCH: float = 0.3

var position: Vector2
var radius: float
var age: float = 0.0
var velocity := Vector2.ZERO

var _sagged: float = 0.0

func _init(at: Vector2, size: float) -> void:
	position = at
	radius = size


func move(delta: float) -> void:
	var sag := smoothstep(0.0, SAG_TIME, age)
	position.y += (sag - _sagged) * SAG_DISTANCE * radius
	_sagged = sag
	position += velocity * delta


## xy: jiggle squash across and down; zw: the direction the whole drop is
## lengthened along, scaled by how much (0.3 is 30% longer).
func shape() -> Vector4:
	var jiggle := exp(-age * JIGGLE_SETTLE) * sin(age * JIGGLE_RATE) * JIGGLE_SIZE
	var lengthening := (velocity / radius * STRETCH_PER_SPEED).limit_length(MAX_STRETCH)
	return Vector4(1.0 + jiggle, 1.0 - jiggle, lengthening.x, lengthening.y)
