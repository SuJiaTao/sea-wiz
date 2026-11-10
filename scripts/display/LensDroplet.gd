extends RefCounted
class_name LensDroplet
## One water drop on the lens: round, heavier at the bottom. It jiggles when
## it lands, then the camera's motion drags its heavy body away from where it
## landed, stretching a neck, until it lets go and runs off the glass.

const JIGGLE_RATE: float = 38.0
const JIGGLE_SETTLE: float = 7.0
const JIGGLE_SIZE: float = 0.25
const BREAK_STRETCH: float = 2.2
const NECK_RELEASE: float = 4.0
const DRY_START: float = 0.75

var position: Vector2
var anchor: Vector2
var radius: float
var life: float
var age: float = 0.0
var velocity := Vector2.ZERO
var attached: bool = true

var strength: float:
	get:
		return 1.0 - smoothstep(DRY_START, 1.0, age / life)


func _init(at: Vector2, size: float, lifetime: float) -> void:
	position = at
	anchor = at
	radius = size
	life = lifetime


func move(delta: float) -> void:
	position += velocity * delta
	if attached and position.distance_to(anchor) > radius * BREAK_STRETCH:
		attached = false
	if not attached:
		anchor = anchor.lerp(position, clampf(NECK_RELEASE * delta, 0.0, 1.0))


## xy: jiggle stretch across and down; zw: the neck back to where it landed.
func shape() -> Vector4:
	var jiggle := exp(-age * JIGGLE_SETTLE) * sin(age * JIGGLE_RATE) * JIGGLE_SIZE
	var neck := anchor - position
	return Vector4(1.0 + jiggle, 1.0 - jiggle, neck.x, neck.y)
