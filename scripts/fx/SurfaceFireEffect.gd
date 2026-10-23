extends AbstractEffect
class_name SurfaceFireEffect

const STRENGTH_PARAMETER := &"strength"
const COLUMN_PARAMETER := &"column"
const MIN_BURN_TIME: float = 10.0
const BURN_TIME_PER_SIZE: float = 9.0
const FULL_BURN_SHARE: float = 0.55
const FLAME_WIDTH: float = 7.0
const FLAME_HEIGHT: float = 14.0
const SMOKE_PER_SECOND: float = 7.0
const SMOKE_RISE := Vector2(2.0, 5.0)
const SMOKE_SPREAD: float = 1.5
const EMBERS_PER_SECOND: float = 4.0
const EMBER_RISE := Vector2(4.0, 11.0)
const EMBER_SPREAD: float = 3.0

var _position: Vector3
var _size: float
var _burn_time: float
var _flame: MeshInstance3D
var _smoke := EmissionRate.new()
var _sparks := EmissionRate.new()


func _init(at: Vector3, size: float) -> void:
	_position = at
	_size = size
	_burn_time = MIN_BURN_TIME + BURN_TIME_PER_SIZE * size


func _on_spawn(effects: EffectManager) -> void:
	_flame = MeshInstance3D.new()
	_flame.mesh = effects.fire_mesh
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effects.add_child(_flame)
	_flame.global_position = _position
	_flame.scale = Vector3(FLAME_WIDTH * _size, FLAME_HEIGHT * _size, 1.0)
	_flame.set_instance_shader_parameter(COLUMN_PARAMETER, randf())


func _on_step(effects: EffectManager, delta: float) -> void:
	var strength := _strength()
	_flame.set_instance_shader_parameter(STRENGTH_PARAMETER, strength)
	var flame_top := _position + Vector3.UP * FLAME_HEIGHT * _size * strength
	for index in _smoke.due(SMOKE_PER_SECOND * _size * strength, delta):
		effects.smoke.emit(flame_top, _rising(SMOKE_RISE, SMOKE_SPREAD), _size)
	for index in _sparks.due(EMBERS_PER_SECOND * _size * strength, delta):
		effects.embers.emit(_position, _rising(EMBER_RISE, EMBER_SPREAD))
	if age >= _burn_time:
		finish()


func _on_finish(_effects: EffectManager) -> void:
	if is_instance_valid(_flame):
		_flame.queue_free()


func _strength() -> float:
	var remaining := 1.0 - age / _burn_time
	return clampf(remaining / (1.0 - FULL_BURN_SHARE), 0.0, 1.0)


func _rising(speed: Vector2, spread: float) -> Vector3:
	var sideways := Vector3(randfn(0.0, spread), 0.0, randfn(0.0, spread))
	return Vector3.UP * randf_range(speed.x, speed.y) + sideways
