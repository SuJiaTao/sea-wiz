extends AbstractEffect
class_name DeckFireEffect

const FLAME_WIDTH: float = 6.0
const FLAME_HEIGHT: float = 9.5
const MIN_SIZE: float = 0.55
const LAYERS: Array[Vector4] = [
	Vector4(0.0, 0.0, 0.0, 1.0),
	Vector4(1.6, 0.0, 1.2, 0.75),
	Vector4(-1.5, 0.0, 0.8, 0.7),
	Vector4(0.6, 0.0, -1.5, 0.65),
	Vector4(-0.8, 0.0, -1.1, 0.55),
]
const BILLOWS_PER_SECOND: float = 1.5
const BILLOW_RISE := Vector2(1.5, 4.0)
const BILLOW_SPREAD: float = 0.9
const BILLOW_SCALE: float = 0.35
const BILLOW_LIFT: float = 0.35
const SMOKE_PER_SECOND: float = 4.0
const SMOKE_SCALE: float = 0.5
const SMOKE_LIFE: float = 0.45
const SMOKE_RISE := Vector2(2.0, 4.5)
const SMOKE_SPREAD: float = 1.2
const EMBERS_PER_SECOND: float = 5.0
const EMBER_RISE := Vector2(3.0, 9.0)
const EMBER_SPREAD: float = 2.5
const EXTINGUISHED_STRENGTH: float = 0.12

var _anchor: Node3D
var _strength: float
var _flames: Array[FlameCard] = []
var _smoke := EmissionRate.new()
var _sparks := EmissionRate.new()
var _billows := EmissionRate.new()


func _init(anchor: Node3D, strength: float) -> void:
	_anchor = anchor
	_strength = clampf(strength, 0.0, 1.0)


func grow(amount: float) -> void:
	_strength = minf(_strength + amount, 1.0)


func dampen(factor: float) -> bool:
	_strength *= factor
	if _strength >= EXTINGUISHED_STRENGTH:
		return true
	finish()
	return false


func _on_spawn(effects: EffectManager) -> void:
	for layer in LAYERS:
		_add_flame(effects, Vector3(layer.x, layer.y, layer.z), layer.w)


func _on_step(effects: EffectManager, delta: float) -> void:
	if not is_instance_valid(_anchor) or not _anchor.is_inside_tree():
		finish()
		return
	var base := _anchor.global_position
	var burning := _strength if base.y > effects.sea_level() else 0.0
	var size := lerpf(MIN_SIZE, 1.0, burning)
	for index in _flames.size():
		var layer := LAYERS[index].w
		_flames[index].resize(FLAME_WIDTH * size * layer, FLAME_HEIGHT * size * layer)
		_flames[index].set_strength(burning)
	var flame_top := base + Vector3.UP * FLAME_HEIGHT * size * burning
	for index in _smoke.due(SMOKE_PER_SECOND * burning, delta):
		effects.smoke.emit(flame_top, _rising(SMOKE_RISE, SMOKE_SPREAD), SMOKE_SCALE * size, SMOKE_LIFE)
	var billow_base := base + Vector3.UP * FLAME_HEIGHT * size * burning * BILLOW_LIFT
	for index in _billows.due(BILLOWS_PER_SECOND * burning, delta):
		effects.fireballs.emit(billow_base, _rising(BILLOW_RISE, BILLOW_SPREAD), BILLOW_SCALE * size)
	for index in _sparks.due(EMBERS_PER_SECOND * burning, delta):
		effects.embers.emit(base, _rising(EMBER_RISE, EMBER_SPREAD))


func _on_finish(_effects: EffectManager) -> void:
	for flame in _flames:
		if is_instance_valid(flame):
			flame.queue_free()


func _add_flame(effects: EffectManager, offset: Vector3, layer_scale: float) -> void:
	var flame := FlameCard.new(effects.fire_mesh)
	_anchor.add_child(flame)
	flame.position = offset
	flame.resize(FLAME_WIDTH * layer_scale, FLAME_HEIGHT * layer_scale)
	_flames.append(flame)


func _rising(speed: Vector2, spread: float) -> Vector3:
	var sideways := Vector3(randfn(0.0, spread), 0.0, randfn(0.0, spread))
	return Vector3.UP * randf_range(speed.x, speed.y) + sideways
