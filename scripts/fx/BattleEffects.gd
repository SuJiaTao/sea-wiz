extends Node
class_name BattleEffects

# The big set pieces: fires breaking out on enemy ships as they are hit, ships
# sinking once beaten, motherships tearing open the sky as they arrive, and
# the moon leaving its place in the sky when it is thrown at us.

const SHIP_FINAL_FIRE: float = 1.0
const WARP_HEAT: float = 0.5
const WARP_DOME_SHARE: float = 0.35
const MOON_DISTANCE: float = 5500.0
const MOON_HIDDEN := {"moon_color": Color.BLACK, "moon_glow": 0.0, "moon_halo": 0.0}

@export var enemies: EnemyManager
@export var effects: EffectManager
@export var thermal: ThermalView
@export var environment: WorldEnvironment

var _sky_moon: Dictionary = {}


func _ready() -> void:
	enemies.enemy_created.connect(_on_enemy_created)
	enemies.enemy_killed.connect(_on_enemy_killed)


func _on_enemy_created(enemy: AbstractEnemy) -> void:
	if enemy is SurfaceShipEnemy:
		(enemy as SurfaceShipEnemy).fire_started.connect(_on_ship_fire)
	elif enemy is MothershipEnemy:
		(enemy as MothershipEnemy).warped_in.connect(_on_warped_in)
	elif enemy is MoonEnemy:
		_tear_moon_from_sky(enemy as MoonEnemy)


## The thrown moon starts exactly where the painted one hung, which goes dark.
func _tear_moon_from_sky(moon: MoonEnemy) -> void:
	var sky := _sky()
	var bearing := deg_to_rad(sky.get_shader_parameter("moon_bearing_deg"))
	var elevation := deg_to_rad(sky.get_shader_parameter("moon_elevation_deg"))
	var toward := Vector3(sin(bearing) * cos(elevation), sin(elevation), -cos(bearing) * cos(elevation))
	moon.global_position = moon.target_position + toward * MOON_DISTANCE
	for key: String in MOON_HIDDEN:
		if not _sky_moon.has(key):
			_sky_moon[key] = sky.get_shader_parameter(key)
		sky.set_shader_parameter(key, MOON_HIDDEN[key])


## The sky material outlives a restart, so the moon is put back on the way out.
func _exit_tree() -> void:
	for key: String in _sky_moon:
		_sky().set_shader_parameter(key, _sky_moon[key])


func _sky() -> ShaderMaterial:
	return environment.environment.sky.sky_material as ShaderMaterial


func _on_ship_fire(spot: Node3D, strength: float) -> void:
	effects.spawn(DeckFireEffect.new(spot, strength))


func _on_warped_in(at: Vector3, size: float) -> void:
	effects.spawn(ShockDomeEffect.new(at, size * WARP_DOME_SHARE))
	thermal.heat_burst(WARP_HEAT)


func _on_enemy_killed(enemy: AbstractEnemy, _weapon_source: DamageSource) -> void:
	var ship := enemy as SurfaceShipEnemy
	if ship == null:
		return
	var spots := ship.burning_spots()
	var hull := ship.detach_visuals()
	if not effects.spawn(SinkingShipEffect.new(hull)):
		hull.queue_free()
		return
	for spot in spots:
		effects.spawn(DeckFireEffect.new(spot, SHIP_FINAL_FIRE))
