extends MultiMeshInstance3D
class_name MissileSmokeRenderer

const MAX_PUFFS := 1800
const PUFF_LIFE := Vector2(1.7, 2.7)

var sensor: Camera3D

var _positions := PackedVector3Array()
var _velocities := PackedVector3Array()
var _life := PackedFloat32Array()
var _max_life := PackedFloat32Array()
var _sizes := PackedFloat32Array()
var _count: int = 0
var _launch_sound: AudioStream
var _audio_pool: Array[AudioStreamPlayer3D] = []
var _audio_index: int = 0


func _ready() -> void:
	_positions.resize(MAX_PUFFS)
	_velocities.resize(MAX_PUFFS)
	_life.resize(MAX_PUFFS)
	_max_life.resize(MAX_PUFFS)
	_sizes.resize(MAX_PUFFS)
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = ProjectileBatch.make_material(true)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = MAX_PUFFS
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	if ResourceLoader.exists("res://audio/missile_launch.wav"):
		_launch_sound = load("res://audio/missile_launch.wav")
	for index in 6:
		var player := AudioStreamPlayer3D.new()
		player.unit_size = 180.0
		player.max_distance = 4000.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player)
		_audio_pool.append(player)


func emit_puff(from_position: Vector3, to_position: Vector3, soft: bool) -> void:
	if _count >= MAX_PUFFS:
		return
	var backward := (from_position - to_position).normalized()
	_positions[_count] = to_position + backward * 1.2
	_velocities[_count] = backward * randf_range(1.0, 5.0) + Vector3(
		randf_range(-1.2, 1.2), randf_range(-0.4, 1.4), randf_range(-1.2, 1.2)
	)
	var lifetime := randf_range(PUFF_LIFE.x, PUFF_LIFE.y)
	if soft:
		lifetime *= 0.45
	_life[_count] = lifetime
	_max_life[_count] = lifetime
	_sizes[_count] = randf_range(1.1, 2.0) * (1.6 if soft else 1.0)
	_count += 1


func play_launch(at: Vector3) -> void:
	if _launch_sound == null or _audio_pool.is_empty():
		return
	var player := _audio_pool[_audio_index]
	_audio_index = (_audio_index + 1) % _audio_pool.size()
	player.global_position = at
	player.stream = _launch_sound
	player.volume_db = -1.0
	player.pitch_scale = randf_range(0.92, 1.08)
	player.play()


func clear_all() -> void:
	_count = 0
	multimesh.visible_instance_count = 0


func _physics_process(delta: float) -> void:
	var index := 0
	while index < _count:
		_life[index] -= delta
		if _life[index] <= 0.0:
			_count -= 1
			if index != _count:
				_positions[index] = _positions[_count]
				_velocities[index] = _velocities[_count]
				_life[index] = _life[_count]
				_max_life[index] = _max_life[_count]
				_sizes[index] = _sizes[_count]
			continue
		var velocity := _velocities[index]
		velocity *= 1.0 - clampf(delta * 1.5, 0.0, 0.9)
		velocity.y += 1.6 * delta
		_velocities[index] = velocity
		_positions[index] += velocity * delta
		index += 1


func _process(_delta: float) -> void:
	var inverse := global_transform.affine_inverse()
	var has_sensor := is_instance_valid(sensor)
	var cull := 7.0
	if has_sensor and sensor.fov < 32.0:
		cull = 45.0
	multimesh.visible_instance_count = _count
	for index in _count:
		var remaining := _life[index] / maxf(_max_life[index], 0.001)
		var size := _sizes[index] * (1.0 + (1.0 - remaining) * 4.2)
		var heat := lerpf(0.30, 2.4, pow(remaining, 2.6))
		var alpha := clampf(remaining * 1.5, 0.0, 0.85)
		var color := Color(heat, heat, heat * 0.95, alpha)
		var instance_transform := Transform3D(
			Basis.from_scale(Vector3.ONE * size), _positions[index]
		)
		if has_sensor and _positions[index].distance_squared_to(
			sensor.global_position
		) < cull * cull:
			instance_transform.basis = Basis.from_scale(Vector3.ZERO)
			color = Color(0, 0, 0, 0)
		multimesh.set_instance_transform(index, inverse * instance_transform)
		multimesh.set_instance_color(index, color)
