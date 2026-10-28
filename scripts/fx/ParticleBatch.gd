extends MultiMeshInstance3D
class_name ParticleBatch

const FLOATS_PER_INSTANCE := 16
const SCALE_X := 0
const ORIGIN_X := 3
const SCALE_Y := 5
const ORIGIN_Y := 7
const SCALE_Z := 10
const ORIGIN_Z := 11
const PROGRESS := 12
const SEED := 13
const ZOOMED_FOV := 32.0
const WORLD_BOUNDS := AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))

@export var style: ParticleStyle
@export var wind: WindField
@export var capacity: int = 1000
@export var near_cull: float = 0.0
@export var zoom_near_cull: float = 0.0

var sensor: Camera3D

var _particles: ParticleBuffer
var _instances := PackedFloat32Array()


static func random_direction() -> Vector3:
	return Vector3(randfn(0.0, 1.0), randfn(0.0, 1.0), randfn(0.0, 1.0)).normalized()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_particles = ParticleBuffer.new(capacity)
	_instances.resize(capacity * FLOATS_PER_INSTANCE)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = style.mesh
	multimesh.instance_count = capacity
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = WORLD_BOUNDS


func emit(
	position: Vector3,
	velocity: Vector3,
	size_scale: float = 1.0,
	life_scale: float = 1.0
) -> void:
	_particles.add(
		position, velocity, style.random_lifetime() * life_scale, style.random_size() * size_scale
	)


func burst(
	position: Vector3,
	count: int,
	speed: Vector2,
	size_scale: float = 1.0,
	carried: Vector3 = Vector3.ZERO
) -> void:
	for index in count:
		emit(position, carried + random_direction() * randf_range(speed.x, speed.y), size_scale)


func clear_all() -> void:
	_particles.clear()
	multimesh.visible_instance_count = 0


func _process(delta: float) -> void:
	_particles.advance(
		delta,
		Vector3.UP * style.vertical_acceleration(),
		_wind_velocity() * style.wind_factor,
		style.drag
	)
	_write_instances()


func _wind_velocity() -> Vector3:
	return wind.velocity if wind != null else Vector3.ZERO


func _cull_distance() -> float:
	if not is_instance_valid(sensor):
		return 0.0
	return zoom_near_cull if sensor.fov < ZOOMED_FOV else near_cull


func _write_instances() -> void:
	var positions := _particles.positions
	var sizes := _particles.sizes
	var ages := _particles.ages
	var lifetimes := _particles.lifetimes
	var seeds := _particles.seeds
	var cull := _cull_distance()
	var eye := sensor.global_position if cull > 0.0 else Vector3.ZERO
	for index in _particles.count:
		var position := positions[index]
		var size := sizes[index]
		if cull > 0.0 and position.distance_squared_to(eye) < cull * cull:
			size = 0.0
		var offset := index * FLOATS_PER_INSTANCE
		_instances[offset + SCALE_X] = size
		_instances[offset + SCALE_Y] = size
		_instances[offset + SCALE_Z] = size
		_instances[offset + ORIGIN_X] = position.x
		_instances[offset + ORIGIN_Y] = position.y
		_instances[offset + ORIGIN_Z] = position.z
		_instances[offset + PROGRESS] = ages[index] / lifetimes[index]
		_instances[offset + SEED] = seeds[index]
	multimesh.buffer = _instances
	multimesh.visible_instance_count = _particles.count
