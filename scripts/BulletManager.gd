extends Node3D
class_name BulletManager
## Every round in the air, held in flat arrays and drawn with one MultiMesh.
## At 4500 rpm there are ~150 rounds alive at once, so no per-bullet nodes and
## no physics engine: collision is a continuous segment-vs-sphere test, which
## also means rounds cannot tunnel through a small drone at 900 m/s.

signal hit_enemy(enemy: Enemy, world_point: Vector3, killed: bool)
signal round_expired()

const MAX_BULLETS := 900
const GRAVITY := 9.81

@export var damage: float = 10.0
@export var tracer_length: float = 8.0
@export var tracer_width: float = 0.085
## Rounds nearer than this are not drawn. At 3x sensor zoom a tracer a few
## metres from the lens smears into a screen-wide bar; you would not resolve
## a 20mm round at that range anyway.
@export var near_cull: float = 70.0

## Set by Game so the near cull knows where the sensor is.
var sensor: Camera3D = null

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _life := PackedFloat32Array()
var _count: int = 0

var _mm: MultiMesh
var _mmi: MultiMeshInstance3D


func _ready() -> void:
	_pos.resize(MAX_BULLETS)
	_vel.resize(MAX_BULLETS)
	_life.resize(MAX_BULLETS)

	# A thin square prism one unit long on Z, stretched per-instance. Square
	# rather than round: at 320x180 a cylinder costs triangles and reads the
	# same, and hard edges keep the streak looking like a round in flight.
	var mesh := BoxMesh.new()
	mesh.size = Vector3(tracer_width, tracer_width, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1, 1)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = m

	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = mesh
	_mm.instance_count = MAX_BULLETS
	_mm.visible_instance_count = 0

	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = _mm
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Rounds travel far from this node's origin; keep it out of the culler.
	_mmi.custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	add_child(_mmi)


func spawn(origin: Vector3, velocity: Vector3, lifetime: float = 3.2) -> void:
	if _count >= MAX_BULLETS:
		return
	_pos[_count] = origin
	_vel[_count] = velocity
	_life[_count] = lifetime
	_count += 1


func active_count() -> int:
	return _count


func clear_all() -> void:
	_count = 0
	_mm.visible_instance_count = 0


func _physics_process(delta: float) -> void:
	var enemies := get_tree().get_nodes_in_group("enemy")

	var i := 0
	while i < _count:
		var p: Vector3 = _pos[i]
		var v: Vector3 = _vel[i]
		v.y -= GRAVITY * delta
		var np: Vector3 = p + v * delta

		var remove := false
		var life: float = _life[i] - delta
		if life <= 0.0 or np.y < 0.0:
			remove = true
		else:
			var hit_enemy_node: Enemy = null
			var hit_point := Vector3.ZERO
			var best_t := 2.0
			for e in enemies:
				var en := e as Enemy
				if en == null or not en.alive:
					continue
				# Enemy owns its hitbox: one sphere for small craft, a chain of
				# volumes for big ships.
				var t := en.segment_hit(p, np)
				if t >= 0.0 and t < best_t:
					best_t = t
					hit_enemy_node = en
					hit_point = p.lerp(np, t)
			if hit_enemy_node != null:
				var killed := hit_enemy_node.take_damage(damage, hit_point)
				hit_enemy.emit(hit_enemy_node, hit_point, killed)
				remove = true

		if remove:
			if life <= 0.0 or np.y < 0.0:
				round_expired.emit()
			_count -= 1
			if i != _count:
				_pos[i] = _pos[_count]
				_vel[i] = _vel[_count]
				_life[i] = _life[_count]
			continue

		_pos[i] = np
		_vel[i] = v
		_life[i] = life
		i += 1

	_redraw()


func _redraw() -> void:
	_mm.visible_instance_count = _count
	var eye := sensor.global_position if sensor != null else Vector3.INF
	# Only bites in the narrow field; at wide FOV the near rounds read fine.
	var cull: float = near_cull if (sensor != null and sensor.fov < 32.0) else 10.0
	for i in _count:
		if eye != Vector3.INF and _pos[i].distance_squared_to(eye) < cull * cull:
			_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), _pos[i]))
			_mm.set_instance_color(i, Color(0, 0, 0, 0))
			continue
		var v: Vector3 = _vel[i]
		var dir := v.normalized() if v.length_squared() > 0.001 else Vector3.FORWARD
		var b := Basis()
		if absf(dir.dot(Vector3.UP)) < 0.999:
			b = Basis.looking_at(dir, Vector3.UP)
		else:
			b = Basis.looking_at(dir, Vector3.RIGHT)
		# The mesh is 1 unit long on Z; stretch it into a tracer streak.
		#
		# This MUST be a post-multiply. Basis.scaled() applies the scale in
		# PARENT space, so `b.scaled(Vector3(1,1,len))` stretches the round
		# along the world Z axis rather than along its own flight path - which
		# is why tracers looked like horizontal bars when firing east or west.
		b = b * Basis.from_scale(Vector3(1.0, 1.0, tracer_length))
		var xf := Transform3D(b, _pos[i])
		_mm.set_instance_transform(i, xf)
		# Tracers burn out as they go, but never get soft - a round should read
		# as a hard bright line, not a smear.
		var f := clampf(_life[i] / 1.4, 0.45, 1.0)
		_mm.set_instance_color(i, Color(2.6 * f, 2.6 * f, 2.2 * f, 1.0))
