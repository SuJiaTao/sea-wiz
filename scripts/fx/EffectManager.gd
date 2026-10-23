extends Node3D
class_name EffectManager

@export var sea: Node3D
@export var smoke: ParticleBatch
@export var fireballs: ParticleBatch
@export var embers: ParticleBatch
@export var droplets: ParticleBatch
@export var spray: ParticleBatch
@export var ripples: ParticleBatch
@export var fire_mesh: Mesh
@export var splash_style: SplashStyle
@export var max_effects: int = 96

var _effects: Array[AbstractEffect] = []


func spawn(effect: AbstractEffect) -> bool:
	if effect == null or _effects.size() >= max_effects:
		return false
	effect._on_spawn(self)
	if effect._finished:
		effect._on_finish(self)
	else:
		_effects.append(effect)
	return true


func splash(at: Vector3, size: float) -> void:
	spawn(SplashEffect.new(at, size))


func sea_level() -> float:
	return sea.global_position.y


func clear_all() -> void:
	var snapshot: Array[AbstractEffect] = _effects.duplicate()
	for effect in snapshot:
		_retire(effect)
	for batch in [smoke, fireballs, embers, droplets, spray, ripples]:
		batch.clear_all()


func _process(delta: float) -> void:
	var snapshot: Array[AbstractEffect] = _effects.duplicate()
	for effect in snapshot:
		effect.age += delta
		effect._on_step(self, delta)
		if effect._finished:
			_retire(effect)


func _retire(effect: AbstractEffect) -> void:
	_effects.erase(effect)
	effect._on_finish(self)


func _exit_tree() -> void:
	_effects.clear()
