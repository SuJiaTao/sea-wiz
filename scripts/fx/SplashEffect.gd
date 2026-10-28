extends AbstractEffect
class_name SplashEffect

var _position: Vector3
var _size: float


func _init(at: Vector3, size: float) -> void:
	_position = at
	_size = size


func _on_spawn(effects: EffectManager) -> void:
	var style := effects.splash_style
	var reach := sqrt(_size)
	for index in style.droplet_count(_size):
		effects.droplets.emit(
			_position, _upward(style.droplet_spread) * _between(style.droplet_speed) * reach, _size
		)
	for index in style.column_count(_size):
		effects.spray.emit(
			_position, _upward(style.column_spread) * _between(style.column_speed) * reach, _size
		)
	effects.ripples.emit(_position + Vector3.UP * style.ripple_lift, Vector3.ZERO, _size)
	finish()


func _upward(spread: float) -> Vector3:
	return Vector3(randfn(0.0, spread), 1.0, randfn(0.0, spread)).normalized()


func _between(span: Vector2) -> float:
	return randf_range(span.x, span.y)
