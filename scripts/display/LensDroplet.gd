extends RefCounted
class_name LensDroplet
## One water drop on the lens. It jiggles when it lands, sags bottom-heavy,
## stretches as it runs and leaves a thin wet trail, then dries away.

const JIGGLE_RATE: float = 38.0
const JIGGLE_SETTLE: float = 7.0
const JIGGLE_SIZE: float = 0.35
const RUN_STRETCH: float = 0.12
const TRAIL_TIME: float = 0.35
const DRY_START: float = 0.7

var position: Vector2
var radius: float
var life: float
var age: float = 0.0
var velocity := Vector2.ZERO

var strength: float:
	get:
		return 1.0 - smoothstep(DRY_START, 1.0, age / life)


func _init(at: Vector2, size: float, lifetime: float) -> void:
	position = at
	radius = size
	life = lifetime


## xy: how far the drop is stretched across and down; zw: its trail back along the run.
func shape() -> Vector4:
	var jiggle := exp(-age * JIGGLE_SETTLE) * sin(age * JIGGLE_RATE) * JIGGLE_SIZE
	var run := velocity.abs() / radius * RUN_STRETCH
	var trail := -velocity * TRAIL_TIME
	return Vector4((1.0 + jiggle) * (1.0 + run.x), (1.0 - jiggle) * (1.0 + run.y), trail.x, trail.y)
