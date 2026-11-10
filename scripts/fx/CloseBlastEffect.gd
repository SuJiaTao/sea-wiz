extends AbstractEffect
class_name CloseBlastEffect
## A big blast right beside the camera: fireball, smoke and debris, but no
## shock dome, which would swallow the whole view from this close.

const FIREBALL_SCALE: float = 0.9
const STREAMERS := Vector2i(5, 8)
const DEBRIS_PER_SIZE: int = 60
const DEBRIS_SPEED := Vector2(20.0, 70.0)

var _position: Vector3
var _size: float


func _init(at: Vector3, size: float) -> void:
	_position = at
	_size = size


func _on_spawn(effects: EffectManager) -> void:
	effects.spawn(ExplosionEffect.new(_position, Vector3.ZERO, _size * FIREBALL_SCALE))
	effects.spawn(SmokeColumnEffect.new(_position, _size))
	for index in randi_range(STREAMERS.x, STREAMERS.y):
		effects.spawn(SmokeStreamerEffect.new(_position, _size))
	effects.embers.burst(_position, DEBRIS_PER_SIZE * ceili(_size), DEBRIS_SPEED * sqrt(_size))
	finish()
