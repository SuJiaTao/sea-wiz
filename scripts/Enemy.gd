extends Node3D
class_name Enemy
## One airborne contact. All behaviour is driven by its EnemyDB entry, so new
## threat types need no new code.

signal died(enemy: Enemy, killed_by_player: bool)
signal leaked(enemy: Enemy)
signal launch_requested(type_id: String, origin: Vector3, forward: Vector3)
signal bay_opened(enemy: Enemy, count: int)
signal flares_popped(origin: Vector3, carrier_velocity: Vector3)
## Warp ships: the moment it drops out of warp, and the moment it stops.
signal warp_started(enemy: Enemy)
signal warp_arrived(enemy: Enemy)

const LEAK_RADIUS := 55.0   # metres from the mount that counts as an impact
const DESPAWN_RADIUS := 4200.0
## Warp arrival: seconds of heat bloom before it drops in, and how hard it
## brakes. Remaining distance falls off as exp(-WARP_BRAKE * t).
const WARP_CHARGE := 2.6
const WARP_BRAKE := 1.35

var type_id: String = "drone"
var data: Dictionary = {}
var hp: float = 10.0
var max_hp: float = 10.0
## Bounding radius. For small craft it is also the hitbox; big ships use
## `hit_volumes` from EnemyDB and treat this only as a broad-phase check.
var radius: float = 3.0
var speed: float = 80.0
var agility: float = 0.3
var behavior: String = "beeline"
var velocity: Vector3 = Vector3.FORWARD
var score_value: int = 100
var threat: float = 5.0
var display: String = "CONTACT"
var alive: bool = true
var is_boss: bool = false
## True until a warp ship has stopped. It can't be hit or locked before then.
var warping: bool = false
## True while a dead capital ship is breaking up and falling.
var wrecking: bool = false

var _age: float = 0.0
var _weave_seed: float = 0.0
var _pass_target: Vector3 = Vector3.ZERO
var _standoff: float = 0.0
var _hold_alt: float = 0.0
var _orbit_dir: float = 1.0
var _rotors: Array[Node3D] = []
var _weak_points: Array = []
var _volumes: Array = []
var _carrier: Dictionary = {}
var _carrier_timer: float = 0.0
var _carrier_left: int = 0
var _flares: Dictionary = {}
var _flares_left: int = 0
var _flare_cooldown: float = 0.0
var _fires: Array[MeshInstance3D] = []
var _damage_stage: int = 0
var _model: Node3D = null
var _prev_fwd: Vector3 = Vector3.FORWARD
var _bank: float = 0.0
var _fire_scale: float = 1.0
var _warp_phase: int = 0          # 1 = heat bloom, 2 = braking in
var _warp_clock: float = 0.0
var _warp_target: Vector3 = Vector3.ZERO
var _warp_dir: Vector3 = Vector3.FORWARD
var _warp_dist: float = 9000.0
var _warp_bloom: MeshInstance3D = null
var _warp_wake: MeshInstance3D = null
var _wreck_vel: Vector3 = Vector3.ZERO
var _wreck_roll: float = 0.0


func setup(id: String, spawn_pos: Vector3) -> void:
	type_id = id
	data = EnemyDB.get_type(id)
	display = String(data.get("display", "CONTACT"))
	max_hp = float(data.get("hp", 20.0))
	hp = max_hp
	radius = float(data.get("radius", 3.0))
	speed = float(data.get("speed", 80.0))
	agility = float(data.get("agility", 0.3))
	behavior = String(data.get("behavior", "beeline"))
	score_value = int(data.get("score", 100))
	threat = float(data.get("threat", 5.0))
	is_boss = bool(data.get("boss", false))
	_weak_points = data.get("weak_points", [])
	_volumes = data.get("hit_volumes", [])
	_flares = data.get("flares", {})
	_flares_left = int(_flares.get("count", 0))
	_carrier = data.get("carrier", {})
	_carrier_left = int(_carrier.get("count", 0))
	_carrier_timer = float(_carrier.get("first", float(_carrier.get("interval", 6.0)) * 0.6))
	_fire_scale = float(data.get("fire_scale", 1.0))
	_weave_seed = randf() * TAU
	var so: Array = data.get("standoff", [260.0, 520.0])
	_standoff = randf_range(float(so[0]), float(so[1]))
	_hold_alt = spawn_pos.y
	_orbit_dir = 1.0 if randf() < 0.5 else -1.0

	position = spawn_pos
	_model = MeshFactory.build(String(data.get("mesh", "drone")))
	_model.scale = Vector3.ONE * float(data.get("scale", 1.0))
	add_child(_model)
	_collect_rotors(_model)

	velocity = (Vector3(0.0, position.y * 0.15, 0.0) - position).normalized() * speed
	if behavior == "station":
		velocity = Vector3(-position.x, 0.0, -position.z).normalized() * speed
	_pass_target = _pick_pass_target()
	_face_velocity(1.0)
	if data.has("warp"):
		_begin_warp()


func _collect_rotors(n: Node) -> void:
	for c in n.get_children():
		if c is Node3D and (c.name == "Rotor" or c.name == "TailRotor"):
			_rotors.append(c)
		_collect_rotors(c)


func _pick_pass_target() -> Vector3:
	var a := randf() * TAU
	var r := randf_range(160.0, 420.0)
	return Vector3(cos(a) * r, clampf(position.y * randf_range(0.4, 0.9), 25.0, 600.0), sin(a) * r)


func _physics_process(delta: float) -> void:
	if wrecking:
		_wreck_step(delta)
		return
	if not alive:
		return
	_age += delta
	if warping:
		_warp_step(delta)
		return
	_flare_cooldown = maxf(_flare_cooldown - delta, 0.0)

	for r in _rotors:
		r.rotate_y(delta * (60.0 if r.name == "Rotor" else 90.0))

	var desired := _desired_velocity(delta)
	var turn := lerpf(0.5, 5.0, agility) * delta
	velocity = velocity.lerp(desired, clampf(turn, 0.0, 1.0))
	if velocity.length() > 0.001:
		velocity = velocity.normalized() * speed
	position += velocity * delta
	_face_velocity(delta * 6.0)

	if _carrier_left > 0:
		_carrier_timer -= delta
		if _carrier_timer <= 0.0:
			_carrier_timer = float(_carrier.get("interval", 6.0))
			_carrier_left -= 1
			_launch_burst()

	var flat := Vector3(position.x, 0.0, position.z).length()
	if flat < LEAK_RADIUS or position.y < 2.0:
		alive = false
		leaked.emit(self)
		died.emit(self, false)
		return
	if flat > DESPAWN_RADIUS:
		# Wandered out of the engagement envelope: turn it around rather than
		# leaving a contact stuck on the radar forever.
		velocity = (-position).normalized() * speed


## Releases one burst of smaller craft. Ships with `bays` drop them out of the
## belly at those model-space points; anything else launches off the nose.
func _launch_burst() -> void:
	var burst: int = int(_carrier.get("burst", 1))
	var types: Array = _carrier.get("types", [String(_carrier.get("type", "drone"))])
	var bays: Array = _carrier.get("bays", [])
	for k in burst:
		var tid: String = String(types.pick_random())
		var origin: Vector3
		var fwd: Vector3
		if bays.is_empty():
			fwd = -global_transform.basis.z
			origin = global_position + fwd * (radius * 0.6) + Vector3(0, -radius * 0.4, 0)
		else:
			var bay: Vector3 = bays[k % bays.size()]
			origin = _model.to_global(bay)
			# Drop clear of the hull, then head for the ship.
			var inbound := Vector3(-origin.x, 0.0, -origin.z).normalized()
			fwd = (inbound * 0.8 + Vector3.DOWN * 0.55).normalized()
		launch_requested.emit(tid, origin, fwd)
	bay_opened.emit(self, burst)


func _desired_velocity(_delta: float) -> Vector3:
	var to_ship := Vector3.ZERO - position
	var flat_dist := Vector3(position.x, 0.0, position.z).length()

	match behavior:
		"terminal":
			# Sea skimmer: hold altitude, run straight in.
			var d := Vector3(to_ship.x, 0.0, to_ship.z).normalized()
			var hold := float(data.get("alt", [15.0, 25.0])[0])
			d.y = clampf((hold - position.y) * 0.02, -0.25, 0.25)
			return d.normalized() * speed

		"hover":
			var dir := to_ship.normalized()
			var bob := sin(_age * 1.4 + _weave_seed) * 0.12
			if flat_dist < _standoff:
				# Crab sideways while closing slowly.
				var side := dir.cross(Vector3.UP).normalized()
				dir = (dir * 0.35 + side * sin(_age * 0.5 + _weave_seed) * 0.9).normalized()
			dir.y += bob
			return dir.normalized() * speed

		"strafe":
			if position.distance_to(_pass_target) < 180.0:
				_pass_target = _pick_pass_target()
			var d := (_pass_target - position).normalized()
			# Roll in with a bit of jink so it is not a free shot.
			var side := d.cross(Vector3.UP).normalized()
			d = (d + side * sin(_age * 1.1 + _weave_seed) * 0.35 * agility).normalized()
			return d * speed

		"weave":
			var d := to_ship.normalized()
			var side := d.cross(Vector3.UP).normalized()
			var up := side.cross(d).normalized()
			var amp := 0.9 * agility
			d = (d
				+ side * sin(_age * 1.9 + _weave_seed) * amp
				+ up * sin(_age * 1.3 + _weave_seed * 1.7) * amp * 0.6).normalized()
			return d * speed

		"capital":
			var d := Vector3(to_ship.x, 0.0, to_ship.z).normalized()
			var hold := float(data.get("alt", [250.0, 350.0])[0])
			d.y = clampf((hold - position.y) * 0.004, -0.08, 0.08)
			return d.normalized() * speed

		"station":
			# Carrier: close to a standoff ring, then circle the ship broadside
			# while the bay works. It never comes in, so it has to be killed.
			var flat := Vector3(position.x, 0.0, position.z)
			var inward := -flat.normalized()
			var d: Vector3
			if flat_dist > _standoff + 150.0:
				d = inward
			else:
				var tangent := Vector3.UP.cross(inward).normalized() * _orbit_dir
				var err := clampf((flat_dist - _standoff) / 220.0, -0.6, 0.6)
				d = (tangent + inward * err).normalized()
			d.y = clampf((_hold_alt - position.y) * 0.004, -0.06, 0.06)
			return d.normalized() * speed

	# beeline
	return to_ship.normalized() * speed


func _face_velocity(weight: float) -> void:
	if velocity.length_squared() < 0.01:
		return
	var fwd := velocity.normalized()
	if absf(fwd.dot(Vector3.UP)) > 0.985:
		return
	var target := Transform3D().looking_at(fwd, Vector3.UP)
	# Bank into the turn, based on how much the heading changed this frame.
	# Big ships barely bank at all.
	var bank_gain := -14.0 if not is_boss else -3.0
	var bank := clampf(_prev_fwd.cross(fwd).dot(Vector3.UP) * bank_gain, -0.9, 0.9)
	_bank = lerpf(_bank, bank, 0.15)
	target.basis = target.basis.rotated(fwd, _bank)
	_prev_fwd = fwd
	if weight >= 1.0:
		basis = target.basis
	else:
		basis = basis.slerp(target.basis, clampf(weight, 0.0, 1.0)).orthonormalized()


# ---------------------------------------------------------------------------
# Hitboxes
# ---------------------------------------------------------------------------

## Parametric position (0..1) of the first intersection of segment a->b with a
## sphere, or -1.0 if it misses.
static func seg_sphere(a: Vector3, b: Vector3, c: Vector3, r: float) -> float:
	var d := b - a
	var f := a - c
	var aa := d.dot(d)
	if aa < 0.000001:
		return -1.0
	var bb := 2.0 * f.dot(d)
	var cc := f.dot(f) - r * r
	if cc <= 0.0:
		return 0.0 # started inside
	var disc := bb * bb - 4.0 * aa * cc
	if disc < 0.0:
		return -1.0
	disc = sqrt(disc)
	var t1 := (-bb - disc) / (2.0 * aa)
	if t1 >= 0.0 and t1 <= 1.0:
		return t1
	var t2 := (-bb + disc) / (2.0 * aa)
	if t2 >= 0.0 and t2 <= 1.0:
		return t2
	return -1.0


## Where along a->b a round first touches this contact, or -1.0.
##
## Small craft are one sphere. Big ships are a chain of spheres down the hull
## plus the pods and gondola, so a round through empty sky beside a 360 m
## airship misses instead of hitting its bounding sphere.
func segment_hit(a: Vector3, b: Vector3) -> float:
	if warping:
		return -1.0
	var broad := seg_sphere(a, b, global_position, radius)
	if _volumes.is_empty() or broad < 0.0:
		return broad
	# Test in model space: two transforms per round instead of one per volume,
	# and volumes that are nowhere near the segment along the hull are skipped.
	# The hit fraction along the segment is the same in either space.
	var la := _model.to_local(a)
	var lb := _model.to_local(b)
	var zmin := minf(la.z, lb.z)
	var zmax := maxf(la.z, lb.z)
	var best := -1.0
	for v in _volumes:
		var p: Vector3 = v["pos"]
		var r: float = v["radius"]
		if p.z + r < zmin or p.z - r > zmax:
			continue
		var t := seg_sphere(la, lb, p, r)
		if t >= 0.0 and (best < 0.0 or t < best):
			best = t
	return best


## Distance from a point to this contact's surface (negative = inside).
## Used by missile fuzes and blast falloff.
func surface_distance(p: Vector3) -> float:
	if warping:
		return INF
	if _volumes.is_empty():
		return p.distance_to(global_position) - radius
	var best := INF
	var s: float = _model.scale.x
	for v in _volumes:
		best = minf(best, p.distance_to(_model.to_global(v["pos"])) - float(v["radius"]) * s)
	return best


## World positions of the hitbox volumes, for the death sequence.
func volume_points() -> Array:
	var out: Array = []
	for v in _volumes:
		out.append({"pos": _model.to_global(v["pos"]), "radius": float(v["radius"])})
	return out


## Model-space volumes, for effects that have to follow a moving wreck.
func local_volumes() -> Array:
	return _volumes


func model_to_global(local: Vector3) -> Vector3:
	return _model.to_global(local)


func model_scale() -> float:
	return float(data.get("scale", 1.0))


# ---------------------------------------------------------------------------
# Warp arrival
# ---------------------------------------------------------------------------

## Parks the ship at its spawn point as a growing point of heat. When the
## bloom peaks, it drops out of warp far down its heading and brakes into
## that point, ending up broadside to the mount.
func _begin_warp() -> void:
	var w: Dictionary = data["warp"]
	warping = true
	_warp_phase = 1
	_warp_clock = 0.0
	_warp_target = position
	_warp_dist = float(w.get("distance", 9000.0))
	var inward := Vector3(-position.x, 0.0, -position.z).normalized()
	_warp_dir = Vector3.UP.cross(inward).normalized() * _orbit_dir
	velocity = _warp_dir * speed
	basis = Transform3D().looking_at(_warp_dir, Vector3.UP).basis
	_prev_fwd = _warp_dir
	_model.visible = false
	display = String(w.get("unknown", display))

	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 12
	s.rings = 6
	_warp_bloom = MeshInstance3D.new()
	_warp_bloom.mesh = s
	_warp_bloom.material_override = MeshFactory.mat(MeshFactory.EXHAUST)
	_warp_bloom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_warp_bloom.scale = Vector3.ONE * 2.0
	add_child(_warp_bloom)

	# Long hot wake drawn behind the hull while it brakes.
	var b := BoxMesh.new()
	b.size = Vector3(1, 1, 1)
	_warp_wake = MeshInstance3D.new()
	_warp_wake.mesh = b
	_warp_wake.material_override = MeshFactory.mat(MeshFactory.EXHAUST * 0.6)
	_warp_wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_warp_wake.visible = false
	add_child(_warp_wake)


func _warp_step(delta: float) -> void:
	_warp_clock += delta
	if _warp_phase == 1:
		var k := clampf(_warp_clock / WARP_CHARGE, 0.0, 1.0)
		var flicker := 1.0 + sin(_warp_clock * 31.0) * 0.18 * k
		_warp_bloom.scale = Vector3.ONE * (2.0 + 70.0 * k * k * k) * flicker
		if _warp_clock >= WARP_CHARGE:
			_warp_phase = 2
			_warp_clock = 0.0
			_warp_bloom.queue_free()
			_warp_bloom = null
			_model.visible = true
			_warp_wake.visible = true
			warp_started.emit(self)
			_warp_step(0.0)
		return

	var remain := _warp_dist * exp(-WARP_BRAKE * _warp_clock)
	var v := remain * WARP_BRAKE
	position = _warp_target - _warp_dir * remain
	velocity = _warp_dir * v
	# Stretched along its heading while it is still moving absurdly fast.
	var stretch := 1.0 + clampf(v / 1800.0, 0.0, 5.0)
	var bs := model_scale()
	_model.scale = Vector3(bs, bs, bs * stretch)
	var wake_len := clampf(v * 0.35, 0.0, 6000.0)
	var wake_w := clampf(v / 60.0, 4.0, 120.0) * bs
	_warp_wake.scale = Vector3(wake_w, wake_w * 0.6, maxf(wake_len, 0.01))
	_warp_wake.position = Vector3(0, 0, 600.0 * bs * stretch + wake_len * 0.5)
	_warp_wake.visible = wake_len > 20.0

	if remain < 12.0:
		position = _warp_target
		_model.scale = Vector3.ONE * bs
		_warp_wake.queue_free()
		_warp_wake = null
		warping = false
		_warp_phase = 0
		display = String(data.get("display", display))
		_hold_alt = position.y
		_standoff = Vector3(position.x, 0.0, position.z).length()
		velocity = _warp_dir * speed
		warp_arrived.emit(self)


# ---------------------------------------------------------------------------
# Wreck
# ---------------------------------------------------------------------------

## Dead capital ship: stops launching, loses lift and goes into the sea
## nose first with a slow roll. Game schedules the explosions on it.
func begin_wreck() -> void:
	wrecking = true
	_carrier_left = 0
	_wreck_vel = velocity * 0.5
	_wreck_roll = 1.0 if randf() < 0.5 else -1.0
	remove_from_group("enemy")


func _wreck_step(delta: float) -> void:
	_age += delta
	_wreck_vel.y -= 22.0 * delta
	position += _wreck_vel * delta
	rotate_object_local(Vector3.RIGHT, -0.05 * delta)
	rotate_object_local(Vector3.FORWARD, 0.03 * delta * _wreck_roll)


## Countermeasures. A missile seeker asks this when it gets close; the answer
## is either Vector3.INF (no decoy) or the world position of a flare it should
## chase instead.
##
## Wired but dormant: no type in EnemyDB declares "flares" yet. Give a type
##
##     "flares": {"count": 4, "interval": 2.5, "chance": 0.55}
##
## and it starts popping them. `chance` is the probability that any one
## attempt actually breaks the lock.
func try_decoy(seeker_pos: Vector3) -> Vector3:
	if _flares_left <= 0 or not alive:
		return Vector3.INF
	if _flare_cooldown > 0.0:
		return Vector3.INF
	_flare_cooldown = float(_flares.get("interval", 2.5))
	_flares_left -= 1
	flares_popped.emit(global_position, velocity)
	if randf() > float(_flares.get("chance", 0.5)):
		return Vector3.INF
	var away: Vector3 = (seeker_pos - global_position).normalized()
	var side: Vector3 = away.cross(Vector3.UP).normalized()
	return global_position + side * randf_range(-12.0, 12.0) + Vector3.DOWN * 6.0


## Returns the multiplier that applies at a world-space impact point.
func damage_multiplier_at(world_point: Vector3) -> float:
	if _weak_points.is_empty():
		return 1.0
	# Model space, so weak points line up with the hull at any model scale.
	var local := _model.to_local(world_point)
	var best := 1.0
	for wp in _weak_points:
		var p: Vector3 = wp["pos"]
		if local.distance_to(p) <= float(wp["radius"]):
			best = maxf(best, float(wp["mult"]))
	return best


func take_damage(amount: float, world_point: Vector3) -> bool:
	if not alive:
		return false
	var mult := damage_multiplier_at(world_point)
	hp -= amount * mult
	_update_damage_fx(world_point)
	if hp <= 0.0:
		alive = false
		died.emit(self, true)
		return true
	return false


## Small craft trail one hot plume once badly hurt. Big ships catch fire in
## stages, each fire placed where the ship was last hit, so you can read the
## damage you have done straight off the thermal image.
func _update_damage_fx(hit_point: Vector3) -> void:
	var frac := hp / maxf(max_hp, 1.0)
	if _volumes.is_empty():
		if frac <= 0.4 and _fires.is_empty():
			_add_fire(Vector3(0, 0, radius * 0.5), radius * 0.35)
		return
	if _damage_stage < 3 and _fire_scale > 1.0 and frac <= 0.9 and _fires.is_empty():
		# Huge hulls show damage early, or nothing would visibly change for
		# the first ten thousand rounds.
		_add_fire(to_local(hit_point), 9.0 * _fire_scale)
	var stages := [0.75, 0.5, 0.25]
	while _damage_stage < stages.size() and frac <= float(stages[_damage_stage]):
		_damage_stage += 1
		_add_fire(to_local(hit_point), (9.0 + 3.0 * _damage_stage) * _fire_scale)


func add_fire(local_pos: Vector3, r: float) -> void:
	_add_fire(local_pos, r)


func _add_fire(local_pos: Vector3, r: float) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 8
	s.rings = 4
	var f := MeshInstance3D.new()
	f.mesh = s
	f.material_override = MeshFactory.mat(MeshFactory.EXHAUST)
	f.position = local_pos
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(f)
	_fires.append(f)


func _process(_delta: float) -> void:
	if not alive and not wrecking:
		return
	for i in _fires.size():
		var f: MeshInstance3D = _fires[i]
		f.scale = Vector3.ONE * (0.8 + sin(_age * 22.0 + float(i) * 1.7) * 0.25)
