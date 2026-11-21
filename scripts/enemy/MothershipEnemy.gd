extends AbstractEnemy
class_name MothershipEnemy

# A vast ship that warps into the sky: it tears in stretched thin along its
# line of arrival, settles into a slow circle around us, fires missile salvos
# and sends out fighters. It also lights false stars all over the sky that
# break loose and dive at us, and when badly hurt it can hurl the moon.
# Its glowing core takes extra damage.

signal warped_in(at: Vector3, size: float)

const WARP_STRETCH: float = 40.0
const WARP_SQUEEZE: float = 0.02
const MIN_SPEED: float = 0.001
const HOT_ALBEDO: float = 1.0

@export var hover_altitude: float = 650.0
@export var orbit_radius: float = 2200.0
@export var orbit_speed: float = 14.0
@export var warp_time: float = 1.6
@export var warp_size: float = 8.0
@export var target_position := Vector3.ZERO
@export var salvo_interval: float = 7.0
@export var salvo_size: int = 3
@export var missile_scene: PackedScene
@export var fighter_scene: PackedScene
@export var fighter_interval: float = 24.0
@export var fighters_per_launch: int = 2
@export var core: Node3D
@export var core_radius: float = 25.0
@export var core_multiplier: float = 3.0
@export var hull_half_span: float = 120.0
## The hull is dimmed so it reads as a dark mass; only its lights stay hot.
@export_range(0.0, 1.0) var hull_dim: float = 0.6
@export var star_scene: PackedScene
@export var star_interval: float = 9.0
@export var stars_per_seeding: int = 6
@export var star_range: float = 4600.0
@export var star_elevation_deg := Vector2(20.0, 70.0)
## Thrown once, when the hull falls below this share of its strength.
@export var moon_scene: PackedScene
@export_range(0.0, 1.0) var moon_at_health: float = 0.35

var _warp: float = 0.0
var _salvo_clock: float = 0.0
var _fighter_clock: float = 0.0
var _full_scale := Vector3.ONE
var _star_clock: float = 0.0
var _moon_thrown: bool = false

@onready var _hurtbox: Area3D = $Hurtbox


func _create() -> void:
	_dim_hull()
	var from_us := global_position - target_position
	global_position = target_position + Vector3(from_us.x, 0.0, from_us.z).normalized() * orbit_radius
	global_position.y = target_position.y + hover_altitude
	_full_scale = visuals.scale
	visuals.scale = Vector3(_full_scale.x * WARP_SQUEEZE, _full_scale.y * WARP_SQUEEZE, _full_scale.z * WARP_STRETCH)
	_salvo_clock = salvo_interval
	_fighter_clock = fighter_interval * 0.5
	_star_clock = star_interval * 0.5
	warped_in.emit(global_position, warp_size)


func _dim_hull() -> void:
	var dimmed: Dictionary[Material, Material] = {}
	for part in visuals.find_children("*", "MeshInstance3D", true, false):
		var mesh := part as MeshInstance3D
		if mesh.material_override != null:
			mesh.material_override = _dimmed(mesh.material_override, dimmed)
			continue
		for surface in mesh.get_surface_override_material_count():
			mesh.set_surface_override_material(surface, _dimmed(mesh.get_active_material(surface), dimmed))


func _dimmed(paint: Material, cache: Dictionary[Material, Material]) -> Material:
	var base := paint as BaseMaterial3D
	if base == null or base.albedo_color.get_luminance() >= HOT_ALBEDO:
		return paint
	if not cache.has(paint):
		var dark := base.duplicate() as BaseMaterial3D
		dark.albedo_color = base.albedo_color * Color(hull_dim, hull_dim, hull_dim, 1.0)
		cache[paint] = dark
	return cache[paint]


func take_damage(amount: float, world_point: Vector3, weapon_source: DamageSource = null) -> void:
	var on_core := core != null and world_point.distance_to(core.global_position) <= core_radius
	super(amount * (core_multiplier if on_core else 1.0), world_point, weapon_source)


func _on_think(delta: float) -> void:
	if _warp < 1.0:
		_warp = minf(_warp + delta / warp_time, 1.0)
		var settle := 1.0 - pow(1.0 - _warp, 3.0)
		visuals.scale = Vector3(
			lerpf(_full_scale.x * WARP_SQUEEZE, _full_scale.x, settle),
			lerpf(_full_scale.y * WARP_SQUEEZE, _full_scale.y, settle),
			lerpf(_full_scale.z * WARP_STRETCH, _full_scale.z, settle)
		)
		if _warp >= 1.0:
			_hurtbox.collision_layer = COLLISION_LAYER
		return
	_circle(delta)
	# Nothing comes at us from behind the bridge, where we cannot answer.
	if BlindArc.contains(global_position):
		return
	_run_salvos(delta)
	_run_fighters(delta)
	_run_stars(delta)
	_throw_moon_when_beaten()


func _run_stars(delta: float) -> void:
	_star_clock -= delta
	if _star_clock > 0.0 or star_scene == null:
		return
	_star_clock = star_interval
	for index in stars_per_seeding:
		var star := star_scene.instantiate() as FlyingEnemy
		star.target_position = target_position
		var bearing := BlindArc.open_bearing(randf())
		var elevation := deg_to_rad(randf_range(star_elevation_deg.x, star_elevation_deg.y))
		var direction := Vector3(cos(bearing) * cos(elevation), sin(elevation), sin(bearing) * cos(elevation))
		weapon_launched.emit(star, Transform3D(Basis.IDENTITY, target_position + direction * star_range))


func _throw_moon_when_beaten() -> void:
	if hp <= max_hp * moon_at_health:
		_throw_moon()


## A ship killed outright in one blast still gets its last throw away.
func _on_killed() -> void:
	_throw_moon()


func _throw_moon() -> void:
	if _moon_thrown or moon_scene == null:
		return
	_moon_thrown = true
	var moon := moon_scene.instantiate() as AbstractEnemy
	weapon_launched.emit(moon, Transform3D(Basis.IDENTITY, global_position))


func _circle(delta: float) -> void:
	var from_us := global_position - target_position
	var around := Vector3(from_us.x, 0.0, from_us.z).normalized().cross(Vector3.UP)
	velocity = around * orbit_speed
	global_position += velocity * delta
	if velocity.length_squared() > MIN_SPEED:
		look_at(global_position + velocity, Vector3.UP)


func _run_salvos(delta: float) -> void:
	_salvo_clock -= delta
	if _salvo_clock > 0.0 or missile_scene == null:
		return
	_salvo_clock = salvo_interval
	for shot in salvo_size:
		var missile := missile_scene.instantiate() as FlyingEnemy
		missile.target_position = target_position
		missile.velocity = (target_position - global_position).normalized()
		var side := global_basis.x * randf_range(-hull_half_span, hull_half_span)
		weapon_launched.emit(missile, Transform3D(Basis.IDENTITY, global_position + side))


func _run_fighters(delta: float) -> void:
	_fighter_clock -= delta
	if _fighter_clock > 0.0 or fighter_scene == null:
		return
	_fighter_clock = fighter_interval
	for index in fighters_per_launch:
		var fighter := fighter_scene.instantiate() as FlyingEnemy
		fighter.target_position = target_position
		fighter.velocity = (target_position - global_position).normalized()
		var bay := global_position + Vector3.DOWN * 30.0 + global_basis.x * (index - 0.5) * 40.0
		weapon_launched.emit(fighter, Transform3D(Basis.IDENTITY, bay))


func _on_destroy() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.collision_layer = 0
