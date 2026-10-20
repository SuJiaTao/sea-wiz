extends Node3D
class_name FXManager
## Impact sparks and kill blasts, both drawn with MultiMeshes so a sustained
## 75 rounds-per-second hit stream does not allocate a node per spark.

const MAX_SPARKS := 400
const MAX_BLASTS := 48
const SPARK_GRAVITY := 22.0

var _sp_pos := PackedVector3Array()
var _sp_vel := PackedVector3Array()
var _sp_life := PackedFloat32Array()
var _sp_max := PackedFloat32Array()
var _sp_count: int = 0

var _bl_pos := PackedVector3Array()
var _bl_life := PackedFloat32Array()
var _bl_max := PackedFloat32Array()
var _bl_size := PackedFloat32Array()
var _bl_count: int = 0

var _spark_mm: MultiMesh
var _blast_mm: MultiMesh

var _boom: AudioStream
var _ping: AudioStream
var _audio_pool: Array[AudioStreamPlayer3D] = []
var _audio_idx: int = 0
var _hit_sound_cooldown: float = 0.0


func _ready() -> void:
	_sp_pos.resize(MAX_SPARKS); _sp_vel.resize(MAX_SPARKS)
	_sp_life.resize(MAX_SPARKS); _sp_max.resize(MAX_SPARKS)
	_bl_pos.resize(MAX_BLASTS); _bl_life.resize(MAX_BLASTS)
	_bl_max.resize(MAX_BLASTS); _bl_size.resize(MAX_BLASTS)

	_spark_mm = _make_mm(_spark_mesh(), MAX_SPARKS)
	_blast_mm = _make_mm(_blast_mesh(), MAX_BLASTS)

	if ResourceLoader.exists("res://audio/explosion.wav"):
		_boom = load("res://audio/explosion.wav")
	if ResourceLoader.exists("res://audio/impact.wav"):
		_ping = load("res://audio/impact.wav")
	for i in 10:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 220.0
		p.max_distance = 4000.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_audio_pool.append(p)


func _make_mm(mesh: Mesh, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	add_child(mmi)
	return mm


func _spark_mesh() -> Mesh:
	var b := BoxMesh.new()
	b.size = Vector3(0.5, 0.5, 2.0)
	b.material = _fx_material(false)
	return b


func _blast_mesh() -> Mesh:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 8
	s.rings = 4
	s.material = _fx_material(true)
	return s


func _fx_material(transparent: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1, 1)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


func spark_burst(pos: Vector3, count: int = 4, energy: float = 1.0) -> void:
	for i in count:
		if _sp_count >= MAX_SPARKS:
			return
		var dir := Vector3(randfn(0, 1), randfn(0, 1), randfn(0, 1)).normalized()
		_sp_pos[_sp_count] = pos
		_sp_vel[_sp_count] = dir * randf_range(12.0, 55.0) * energy
		var l := randf_range(0.18, 0.55)
		_sp_life[_sp_count] = l
		_sp_max[_sp_count] = l
		_sp_count += 1


func hit(pos: Vector3) -> void:
	spark_burst(pos, 3, 1.0)
	if _hit_sound_cooldown <= 0.0:
		_hit_sound_cooldown = 0.09
		_play(_ping, pos, randf_range(-8.0, -3.0), randf_range(0.85, 1.25))


func explosion(pos: Vector3, size: float) -> void:
	if _bl_count < MAX_BLASTS:
		_bl_pos[_bl_count] = pos
		var l := clampf(0.35 + size * 0.02, 0.35, 1.6)
		_bl_life[_bl_count] = l
		_bl_max[_bl_count] = l
		_bl_size[_bl_count] = size
		_bl_count += 1
	spark_burst(pos, int(clampf(size * 1.6, 8.0, 60.0)), clampf(size * 0.18, 1.0, 5.0))
	_play(_boom, pos, clampf(-12.0 + size * 0.35, -12.0, 4.0),
			clampf(1.5 - size * 0.035, 0.45, 1.5))


func _play(stream: AudioStream, pos: Vector3, vol: float, pitch: float) -> void:
	if stream == null or _audio_pool.is_empty():
		return
	var p := _audio_pool[_audio_idx]
	_audio_idx = (_audio_idx + 1) % _audio_pool.size()
	p.global_position = pos
	p.stream = stream
	p.volume_db = vol
	p.pitch_scale = pitch
	p.play()


func clear_all() -> void:
	_sp_count = 0
	_bl_count = 0
	_spark_mm.visible_instance_count = 0
	_blast_mm.visible_instance_count = 0


func _process(delta: float) -> void:
	_hit_sound_cooldown = maxf(_hit_sound_cooldown - delta, 0.0)

	var i := 0
	while i < _sp_count:
		var v: Vector3 = _sp_vel[i]
		v.y -= SPARK_GRAVITY * delta
		v *= 1.0 - clampf(delta * 1.6, 0.0, 0.9)
		var p: Vector3 = _sp_pos[i] + v * delta
		var life: float = _sp_life[i] - delta
		if life <= 0.0:
			_sp_count -= 1
			if i != _sp_count:
				_sp_pos[i] = _sp_pos[_sp_count]
				_sp_vel[i] = _sp_vel[_sp_count]
				_sp_life[i] = _sp_life[_sp_count]
				_sp_max[i] = _sp_max[_sp_count]
			continue
		_sp_pos[i] = p
		_sp_vel[i] = v
		_sp_life[i] = life
		i += 1

	var j := 0
	while j < _bl_count:
		var life: float = _bl_life[j] - delta
		if life <= 0.0:
			_bl_count -= 1
			if j != _bl_count:
				_bl_pos[j] = _bl_pos[_bl_count]
				_bl_life[j] = _bl_life[_bl_count]
				_bl_max[j] = _bl_max[_bl_count]
				_bl_size[j] = _bl_size[_bl_count]
			continue
		_bl_life[j] = life
		j += 1

	_redraw()


func _redraw() -> void:
	_spark_mm.visible_instance_count = _sp_count
	for i in _sp_count:
		var v: Vector3 = _sp_vel[i]
		var dir := v.normalized() if v.length_squared() > 0.01 else Vector3.FORWARD
		var b := Basis.looking_at(dir, Vector3.UP) if absf(dir.dot(Vector3.UP)) < 0.999 \
				else Basis.looking_at(dir, Vector3.RIGHT)
		var f: float = _sp_life[i] / maxf(_sp_max[i], 0.001)
		# Post-multiply: Basis.scaled() would stretch the spark along world Z
		# instead of along its own travel. Same bug the tracers had.
		b = b * Basis.from_scale(Vector3(f, f, 1.0 + f * 2.5))
		_spark_mm.set_instance_transform(i, Transform3D(b, _sp_pos[i]))
		_spark_mm.set_instance_color(i, Color(3.2 * f, 3.0 * f, 2.4 * f, 1.0))

	_blast_mm.visible_instance_count = _bl_count
	for j in _bl_count:
		var f: float = _bl_life[j] / maxf(_bl_max[j], 0.001)
		var grow := (1.0 - f)
		var s: float = _bl_size[j] * (0.6 + grow * 2.4)
		var b := Basis().scaled(Vector3(s, s, s))
		_blast_mm.set_instance_transform(j, Transform3D(b, _bl_pos[j]))
		var a := f * f
		_blast_mm.set_instance_color(j, Color(4.0 * a, 3.6 * a, 2.8 * a, a))
