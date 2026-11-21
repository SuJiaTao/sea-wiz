extends Node3D
class_name EffectManager

signal wreck_hit_ship(position: Vector3, size: float)
signal wreck_falling(wreck: WreckEffect)
## on_water: the blast went off on the sea, so it is heard as a water blast.
signal shockwave(position: Vector3, size: float, on_water: bool)

@export var sea: Node3D
@export var hull: HullMesh
@export var smoke: ParticleBatch
@export var fireballs: ParticleBatch
@export var embers: ParticleBatch
@export var droplets: ParticleBatch
@export var spray: ParticleBatch
@export var ripples: ParticleBatch
@export var flares: ParticleBatch
@export var flare_smoke: ParticleBatch
@export var fire_mesh: Mesh
@export var shock_dome_mesh: Mesh
@export var splash_style: SplashStyle
@export var max_effects: int = 96

## How hard it is raining, 0 dry to 1 downpour; rain puts fires out.
var wetness: float = 0.0

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


func countermeasures(released: Array[DecoyFlare]) -> void:
	spawn(FlareEffect.new(released))


func deck_height_at(world_position: Vector3) -> float:
	if not is_instance_valid(hull):
		return NAN
	return hull.deck_height_at(world_position)


func sea_level() -> float:
	return sea.global_position.y


## How fast the water's surface carries things floating on it.
func sea_current() -> Vector3:
	return SeaCurrent.velocity((sea as GeometryInstance3D).material_override as ShaderMaterial)


func clear_all() -> void:
	var snapshot: Array[AbstractEffect] = _effects.duplicate()
	for effect in snapshot:
		_retire(effect)
	for batch in [smoke, fireballs, embers, droplets, spray, ripples, flares, flare_smoke]:
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
