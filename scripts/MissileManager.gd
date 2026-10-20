extends Node3D
class_name MissileManager
## Every interceptor in flight plus its smoke trail.
##
## Same approach as BulletManager: flat arrays and two MultiMeshes, no nodes
## and no physics. A missile is a position, a velocity, a target reference and
## a phase; the trail is a stream of puffs that expand and cool.
##
## In a thermal sight a rocket motor is the brightest thing in the sky and the
## smoke behind it stays warm for seconds, so the trail is what actually sells
## the shot - the missile body itself is only a few pixels at these ranges.

signal hit_enemy(enemy: Enemy, world_point: Vector3, killed: bool)
signal detonated(position: Vector3, size: float)
signal missile_spent()

const MAX_MISSILES := 32
const MAX_PUFFS := 1800

# Flight
const LAUNCH_SPEED := 34.0        # soft-launch out of the cell
const BOOST_DELAY := 0.28         # seconds before the motor lights
const CRUISE_SPEED := 265.0
const ACCELERATION := 420.0
const TURN_RATE := 4.6            # rad/s
const TURN_RATE_TERMINAL := 8.5   # rad/s once inside TERMINAL_RANGE
const TERMINAL_RANGE := 260.0
const MAX_FLIGHT := 14.0
const GRAVITY := 9.81

# Warhead. 260 is a clean kill on anything up to a heavy jet; a gunship needs
# three and a Leviathan needs a magazine, so the gun never stops mattering.
const FUZE_RADIUS := 16.0
const BLAST_RADIUS := 26.0
const WARHEAD := 260.0

# Countermeasures
const DECOY_CHECK_RANGE := 520.0

# Trail
const PUFF_INTERVAL := 0.022
const PUFF_LIFE := Vector2(1.7, 2.7)
## Launch smoke is emitted a couple of metres from the sensor head. At 3x zoom
## that fills the frame with a grey wall, so puffs near the lens are skipped -
## the same reasoning as BulletManager's near cull.
const PUFF_NEAR_CULL := 45.0

## Set by Game so the near cull knows where the sensor is.
var sensor: Camera3D = null

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _age := PackedFloat32Array()
var _speed := PackedFloat32Array()
var _puff_t := PackedFloat32Array()
var _last_dist := PackedFloat32Array()
var _decoys := PackedVector3Array()   # Vector3.INF when the seeker is clean
var _decoy_vel := PackedVector3Array()
var _targets: Array = []              # Enemy or null, parallel to the arrays
var _count: int = 0

var _pf_pos := PackedVector3Array()
var _pf_vel := PackedVector3Array()
var _pf_life := PackedFloat32Array()
var _pf_max := PackedFloat32Array()
var _pf_size := PackedFloat32Array()
var _pf_count: int = 0

var _mm: MultiMesh
var _puff_mm: MultiMesh

var _launch_sound: AudioStream
var _audio_pool: Array[AudioStreamPlayer3D] = []
var _audio_idx: int = 0


func _ready() -> void:
	_pos.resize(MAX_MISSILES); _vel.resize(MAX_MISSILES); _age.resize(MAX_MISSILES)
	_speed.resize(MAX_MISSILES); _puff_t.resize(MAX_MISSILES)
	_last_dist.resize(MAX_MISSILES); _decoys.resize(MAX_MISSILES)
	_decoy_vel.resize(MAX_MISSILES)
	_targets.resize(MAX_MISSILES)

	_pf_pos.resize(MAX_PUFFS); _pf_vel.resize(MAX_PUFFS); _pf_life.resize(MAX_PUFFS)
	_pf_max.resize(MAX_PUFFS); _pf_size.resize(MAX_PUFFS)

	_mm = _make_mm(MeshFactory.build_missile_mesh(), MAX_MISSILES)
	_puff_mm = _make_mm(_puff_mesh(), MAX_PUFFS)

	if ResourceLoader.exists("res://audio/missile_launch.wav"):
		_launch_sound = load("res://audio/missile_launch.wav")
	for i in 6:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 180.0
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


func _puff_mesh() -> Mesh:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 6
	s.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1, 1)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	s.material = m
	return s


# ---------------------------------------------------------------------------
# Launching
# ---------------------------------------------------------------------------

## Fire one interceptor. `target` may be null for a dumb shot.
func launch(origin: Vector3, direction: Vector3, target: Enemy) -> bool:
	if _count >= MAX_MISSILES:
		return false
	var i := _count
	_pos[i] = origin
	_vel[i] = direction.normalized() * LAUNCH_SPEED
	_age[i] = 0.0
	_speed[i] = LAUNCH_SPEED
	_puff_t[i] = 0.0
	_last_dist[i] = INF
	_decoys[i] = Vector3.INF
	_decoy_vel[i] = Vector3.ZERO
	_targets[i] = target
	_count += 1
	_play(_launch_sound, origin, -1.0, randf_range(0.92, 1.08))
	return true


func active_count() -> int:
	return _count


func clear_all() -> void:
	_count = 0
	_pf_count = 0
	_mm.visible_instance_count = 0
	_puff_mm.visible_instance_count = 0
	for i in MAX_MISSILES:
		_targets[i] = null


# ---------------------------------------------------------------------------
# Flight
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var i := 0
	while i < _count:
		if _step_missile(i, delta):
			_remove_missile(i)
			continue
		i += 1
	_step_puffs(delta)
	_redraw()


## Advances one missile. Returns true if it should be removed this frame.
func _step_missile(i: int, delta: float) -> bool:
	_age[i] += delta
	var age: float = _age[i]
	var pos: Vector3 = _pos[i]
	var vel: Vector3 = _vel[i]

	# Check validity BEFORE casting: `as` on a freed object is an error.
	var raw = _targets[i]
	var target: Enemy = null
	if raw != null and is_instance_valid(raw) and (raw as Enemy).alive:
		target = raw as Enemy
	elif raw != null:
		_targets[i] = null

	var aim := Vector3.INF

	if age < BOOST_DELAY:
		# Soft launch: coasts out of the cell on gravity alone.
		vel.y -= GRAVITY * delta
	else:
		_speed[i] = minf(_speed[i] + ACCELERATION * delta, CRUISE_SPEED)

		if _decoys[i] != Vector3.INF:
			# Chasing a flare: it falls away and slows.
			_decoy_vel[i] = _decoy_vel[i] * (1.0 - clampf(delta * 1.1, 0.0, 1.0)) \
					+ Vector3.DOWN * 7.0 * delta
			_decoys[i] = _decoys[i] + _decoy_vel[i] * delta
			aim = _decoys[i]
		elif target != null:
			var d_now: float = pos.distance_to(target.global_position)
			# Countermeasures only get a chance once the seeker is close
			# enough to be spoofed.
			if d_now < DECOY_CHECK_RANGE:
				var decoy: Vector3 = target.try_decoy(pos)
				if decoy != Vector3.INF:
					_decoys[i] = decoy
					_decoy_vel[i] = target.velocity * 0.5 + Vector3(
							randf_range(-9, 9), randf_range(-3, 5), randf_range(-9, 9))
					_targets[i] = null
					target = null
					aim = decoy
			if aim == Vector3.INF and target != null:
				# Lead the target by the remaining time of flight.
				var t_go: float = d_now / maxf(_speed[i], 1.0)
				aim = target.global_position + target.velocity * t_go * 0.9

		if aim != Vector3.INF:
			var to_aim: Vector3 = aim - pos
			var dist: float = to_aim.length()
			if dist > 0.01:
				var want: Vector3 = to_aim / dist
				var rate: float = TURN_RATE_TERMINAL if dist < TERMINAL_RANGE else TURN_RATE
				var cur: Vector3 = vel.normalized() if vel.length_squared() > 0.001 \
						else Vector3.UP
				var ang: float = cur.angle_to(want)
				var step: float = minf(rate * delta, ang)
				if ang > 0.0001:
					var axis: Vector3 = cur.cross(want)
					if axis.length_squared() > 0.000001:
						cur = cur.rotated(axis.normalized(), step)
				vel = cur * _speed[i]
			else:
				vel = vel.normalized() * _speed[i]
		else:
			# No seeker input: fly on and gravity-arc.
			vel = vel.normalized() * _speed[i]
			vel.y -= GRAVITY * delta

	var new_pos: Vector3 = pos + vel * delta
	_pos[i] = new_pos
	_vel[i] = vel

	_emit_puffs(i, pos, new_pos, delta, age < BOOST_DELAY)

	# --- Termination ---------------------------------------------------
	if new_pos.y < 0.5:
		_detonate(new_pos, false)
		return true
	if age > MAX_FLIGHT:
		_detonate(new_pos, false)
		return true

	if target != null:
		# Measured to the target's SURFACE, so a 360 m airship fuzes on its
		# hull rather than on a bounding sphere out in empty sky.
		var d: float = target.surface_distance(new_pos)
		# Proximity fuze, plus a closest-approach check so a fast crossing
		# target is not simply flown past between frames.
		if d < FUZE_RADIUS:
			_detonate(new_pos, true)
			return true
		if d < 75.0 and d > _last_dist[i]:
			_detonate(new_pos, true)
			return true
		_last_dist[i] = d
	elif _decoys[i] != Vector3.INF:
		if new_pos.distance_to(_decoys[i]) < FUZE_RADIUS:
			_detonate(new_pos, false)
			return true

	return false


func _remove_missile(i: int) -> void:
	missile_spent.emit()
	_count -= 1
	if i != _count:
		_pos[i] = _pos[_count]
		_vel[i] = _vel[_count]
		_age[i] = _age[_count]
		_speed[i] = _speed[_count]
		_puff_t[i] = _puff_t[_count]
		_last_dist[i] = _last_dist[_count]
		_decoys[i] = _decoys[_count]
		_decoy_vel[i] = _decoy_vel[_count]
		_targets[i] = _targets[_count]
	_targets[_count] = null


## Splash damage. Everything inside the blast takes falloff-scaled damage, so
## a missile into a tight formation can take more than one contact with it.
func _detonate(at: Vector3, on_target: bool) -> void:
	var size := BLAST_RADIUS * (0.75 if not on_target else 1.0)
	detonated.emit(at, size)
	for e in get_tree().get_nodes_in_group("enemy"):
		var en := e as Enemy
		if en == null or not en.alive:
			continue
		var d: float = en.surface_distance(at)
		if d > BLAST_RADIUS:
			continue
		var falloff: float = pow(clampf(1.0 - maxf(d, 0.0) / BLAST_RADIUS, 0.0, 1.0), 0.6)
		var killed: bool = en.take_damage(WARHEAD * falloff, at)
		hit_enemy.emit(en, at, killed)


# ---------------------------------------------------------------------------
# Smoke trail
# ---------------------------------------------------------------------------

func _emit_puffs(i: int, from_pos: Vector3, to_pos: Vector3, delta: float, soft: bool) -> void:
	_puff_t[i] -= delta
	if _puff_t[i] > 0.0:
		return
	_puff_t[i] = PUFF_INTERVAL
	if _pf_count >= MAX_PUFFS:
		return
	# Place the puff where the tail was, not the nose.
	var back: Vector3 = (from_pos - to_pos)
	var p: Vector3 = to_pos + back.normalized() * 1.2 if back.length_squared() > 0.01 else to_pos
	_pf_pos[_pf_count] = p
	_pf_vel[_pf_count] = back.normalized() * randf_range(1.0, 5.0) \
			+ Vector3(randf_range(-1.2, 1.2), randf_range(-0.4, 1.4), randf_range(-1.2, 1.2))
	var l: float = randf_range(PUFF_LIFE.x, PUFF_LIFE.y) * (0.45 if soft else 1.0)
	_pf_life[_pf_count] = l
	_pf_max[_pf_count] = l
	_pf_size[_pf_count] = randf_range(1.1, 2.0) * (1.6 if soft else 1.0)
	_pf_count += 1


func _step_puffs(delta: float) -> void:
	var j := 0
	while j < _pf_count:
		var life: float = _pf_life[j] - delta
		if life <= 0.0:
			_pf_count -= 1
			if j != _pf_count:
				_pf_pos[j] = _pf_pos[_pf_count]
				_pf_vel[j] = _pf_vel[_pf_count]
				_pf_life[j] = _pf_life[_pf_count]
				_pf_max[j] = _pf_max[_pf_count]
				_pf_size[j] = _pf_size[_pf_count]
			continue
		var v: Vector3 = _pf_vel[j] * (1.0 - clampf(delta * 1.5, 0.0, 0.9))
		v.y += 1.6 * delta          # warm smoke rises
		_pf_pos[j] = _pf_pos[j] + v * delta
		_pf_vel[j] = v
		_pf_life[j] = life
		j += 1


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _redraw() -> void:
	_mm.visible_instance_count = _count
	for i in _count:
		var v: Vector3 = _vel[i]
		var dir: Vector3 = v.normalized() if v.length_squared() > 0.001 else Vector3.FORWARD
		var b: Basis
		if absf(dir.dot(Vector3.UP)) < 0.999:
			b = Basis.looking_at(dir, Vector3.UP)
		else:
			b = Basis.looking_at(dir, Vector3.RIGHT)
		# CylinderMesh runs along +Y; stand it up along the flight path.
		b = b * Basis(Vector3(1, 0, 0), deg_to_rad(-90.0))
		_mm.set_instance_transform(i, Transform3D(b, _pos[i]))
		# The motor is lit after the boost delay and blows out the sensor.
		var hot: float = 1.2 if _age[i] < BOOST_DELAY else 3.0
		_mm.set_instance_color(i, Color(hot, hot, hot * 0.92, 1.0))

	_puff_mm.visible_instance_count = _pf_count
	var eye := sensor.global_position if sensor != null else Vector3.INF
	var cull: float = PUFF_NEAR_CULL if (sensor != null and sensor.fov < 32.0) else 7.0
	for j in _pf_count:
		if eye != Vector3.INF and _pf_pos[j].distance_squared_to(eye) < cull * cull:
			_puff_mm.set_instance_transform(j,
					Transform3D(Basis().scaled(Vector3.ZERO), _pf_pos[j]))
			_puff_mm.set_instance_color(j, Color(0, 0, 0, 0))
			continue
		var f: float = _pf_life[j] / maxf(_pf_max[j], 0.001)
		# Expands as it disperses.
		var s: float = _pf_size[j] * (1.0 + (1.0 - f) * 4.2)
		_puff_mm.set_instance_transform(j, Transform3D(Basis().scaled(Vector3(s, s, s)),
				_pf_pos[j]))
		# Hot when fresh, cooling to a warm grey, then thinning out.
		var heat: float = lerpf(0.30, 2.4, pow(f, 2.6))
		var alpha: float = clampf(f * 1.5, 0.0, 0.85)
		_puff_mm.set_instance_color(j, Color(heat, heat, heat * 0.95, alpha))


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
