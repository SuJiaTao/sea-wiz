extends AbstractEffect
class_name SinkingShipEffect

# A ship we sank: it heels over, settles by the stern and slides under,
# still burning until the sea closes over each fire.

const SINK_TIME: float = 28.0
const SINK_DEPTH: float = 40.0
const LIST_DEG: float = 22.0
const TRIM_DEG: float = 9.0
const SMOKE_PER_SECOND: float = 6.0
const SMOKE_SIZE: float = 2.2
const SMOKE_RISE := Vector2(3.0, 7.0)

var _hull: Node3D
var _start: Transform3D
var _list_side: float
var _smoke := EmissionRate.new()


func _init(hull: Node3D) -> void:
	_hull = hull
	_list_side = 1.0 if randf() < 0.5 else -1.0


func _on_spawn(effects: EffectManager) -> void:
	if not is_instance_valid(_hull):
		finish()
		return
	effects.add_child(_hull)
	_start = _hull.global_transform


func _on_step(effects: EffectManager, delta: float) -> void:
	if not is_instance_valid(_hull):
		finish()
		return
	var progress := clampf(age / SINK_TIME, 0.0, 1.0)
	var settle := progress * progress
	var tilt := Basis(Vector3.FORWARD, deg_to_rad(LIST_DEG) * _list_side * sqrt(progress))
	tilt = tilt * Basis(Vector3.RIGHT, deg_to_rad(TRIM_DEG) * settle)
	_hull.global_transform = Transform3D(_start.basis * tilt, _start.origin + Vector3.DOWN * SINK_DEPTH * settle)
	var top := _hull.global_position + Vector3.UP * SINK_DEPTH * (1.0 - settle) * 0.3
	for puff in _smoke.due(SMOKE_PER_SECOND * (1.0 - progress), delta):
		var drift := Vector3(randfn(0.0, 1.0), randf_range(SMOKE_RISE.x, SMOKE_RISE.y), randfn(0.0, 1.0))
		effects.smoke.emit(top, drift, SMOKE_SIZE)
	if progress >= 1.0:
		finish()


func _on_finish(_effects: EffectManager) -> void:
	if is_instance_valid(_hull):
		_hull.queue_free()
