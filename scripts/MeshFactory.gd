extends RefCounted
class_name MeshFactory
## Builds every airframe out of primitives, so the project has zero binary
## art dependencies. Every model is built facing -Z (Godot's forward).
##
## "Heat" is expressed purely as albedo brightness on unshaded materials:
## the thermal post-process reads luminance, so 0.0 is ambient-cold and
## values above 1.0 blow out into the sensor bloom the way a jet exhaust does.

const COLD := 0.30      # unheated skin
const WARM := 0.55      # leading edges, friction-heated surfaces
const HOT := 0.95       # engine housings
const EXHAUST := 2.60   # raw plume - deliberately over 1.0

static var _mat_cache: Dictionary = {}


## Unshaded grey material. `v` may exceed 1.0 to drive glow.
static func mat(v: float) -> StandardMaterial3D:
	var key := snappedf(v, 0.01)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(v, v, v, 1.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_mat_cache[key] = m
	return m


static func _mi(mesh: Mesh, v: float, pos := Vector3.ZERO, rot := Vector3.ZERO,
		scl := Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat(v)
	n.position = pos
	n.rotation = rot
	n.scale = scl
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


static func _box(size: Vector3, v: float, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mi(b, v, pos, rot)


static func _cyl(radius: float, height: float, v: float, pos := Vector3.ZERO,
		rot := Vector3.ZERO, top_radius := -1.0, segments := 8) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = radius if top_radius < 0.0 else top_radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	return _mi(c, v, pos, rot)


static func _sph(radius: float, v: float, pos := Vector3.ZERO) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 8
	s.rings = 4
	return _mi(s, v, pos)


static func _prism(size: Vector3, v: float, pos := Vector3.ZERO, rot := Vector3.ZERO,
		left_to_right := 0.5) -> MeshInstance3D:
	var p := PrismMesh.new()
	p.size = size
	p.left_to_right = left_to_right
	return _mi(p, v, pos, rot)


# ---------------------------------------------------------------------------
# Airframes
# ---------------------------------------------------------------------------

static func build(kind: String) -> Node3D:
	match kind:
		"jet": return _jet()
		"heavy_jet": return _heavy_jet()
		"helo": return _helo()
		"drone": return _drone()
		"missile": return _missile()
		"gunship": return _gunship()
		"dropship": return _dropship()
		"leviathan": return _leviathan()
		"mothership": return _mothership()
		"dreadnought": return _dreadnought()
		"orb": return _orb()
	return _drone()


static func _jet() -> Node3D:
	var root := Node3D.new()
	# Fuselage: a cylinder lying along Z.
	root.add_child(_cyl(0.85, 14.0, COLD, Vector3(0, 0, 0), Vector3(deg_to_rad(90), 0, 0), 0.35))
	# Nose cone.
	root.add_child(_cyl(0.85, 3.0, WARM, Vector3(0, 0, -8.0), Vector3(deg_to_rad(-90), 0, 0), 0.05))
	# Canopy.
	root.add_child(_sph(0.75, WARM * 1.2, Vector3(0, 0.6, -3.2)))
	# Delta wings.
	for side in [-1.0, 1.0]:
		var w := _box(Vector3(9.0, 0.28, 5.0), COLD, Vector3(side * 5.0, -0.1, 1.2))
		w.rotation = Vector3(0, deg_to_rad(-side * 18.0), 0)
		root.add_child(w)
		# Warm leading edge.
		var le := _box(Vector3(9.0, 0.34, 0.7), WARM, Vector3(side * 5.0, -0.1, -1.1))
		le.rotation = Vector3(0, deg_to_rad(-side * 18.0), 0)
		root.add_child(le)
	# Twin tails.
	for side in [-1.0, 1.0]:
		var t := _box(Vector3(0.22, 3.0, 3.0), COLD, Vector3(side * 1.6, 1.6, 5.0))
		t.rotation = Vector3(0, 0, deg_to_rad(side * 12.0))
		root.add_child(t)
	# Horizontal stabs.
	for side in [-1.0, 1.0]:
		root.add_child(_box(Vector3(4.0, 0.22, 2.2), COLD, Vector3(side * 2.4, 0.0, 6.2)))
	# Engine cans + plume.
	for side in [-1.0, 1.0]:
		root.add_child(_cyl(0.75, 2.2, HOT, Vector3(side * 0.9, 0, 6.6), Vector3(deg_to_rad(90), 0, 0)))
		root.add_child(_cyl(0.55, 3.6, EXHAUST, Vector3(side * 0.9, 0, 8.8), Vector3(deg_to_rad(90), 0, 0), 0.12))
	return root


static func _heavy_jet() -> Node3D:
	var root := Node3D.new()
	root.add_child(_cyl(2.4, 34.0, COLD, Vector3.ZERO, Vector3(deg_to_rad(90), 0, 0)))
	root.add_child(_cyl(2.4, 6.0, WARM, Vector3(0, 0, -19.0), Vector3(deg_to_rad(-90), 0, 0), 0.25))
	for side in [-1.0, 1.0]:
		var w := _box(Vector3(26.0, 0.7, 7.0), COLD, Vector3(side * 14.0, -0.6, 2.0))
		w.rotation = Vector3(0, deg_to_rad(-side * 12.0), 0)
		root.add_child(w)
		# Four podded engines, hot.
		for i in 2:
			var ex: float = side * (6.0 + i * 6.5)
			root.add_child(_cyl(1.5, 5.0, HOT, Vector3(ex, -2.0, 0.0), Vector3(deg_to_rad(90), 0, 0)))
			root.add_child(_cyl(1.1, 4.0, EXHAUST * 0.7, Vector3(ex, -2.0, 3.4), Vector3(deg_to_rad(90), 0, 0), 0.2))
	root.add_child(_box(Vector3(0.8, 9.0, 8.0), COLD, Vector3(0, 5.0, 15.0)))
	root.add_child(_box(Vector3(14.0, 0.6, 4.0), COLD, Vector3(0, 1.2, 16.0)))
	return root


static func _helo() -> Node3D:
	var root := Node3D.new()
	# Cabin.
	root.add_child(_box(Vector3(3.0, 3.2, 9.0), COLD, Vector3(0, 0, -1.0)))
	root.add_child(_sph(1.7, WARM, Vector3(0, 0.2, -5.2)))
	# Tail boom + fin.
	root.add_child(_cyl(0.45, 9.0, COLD, Vector3(0, 0.6, 7.0), Vector3(deg_to_rad(90), 0, 0)))
	root.add_child(_box(Vector3(0.22, 3.0, 2.0), COLD, Vector3(0, 2.2, 11.0)))
	# Engine deck - the hottest thing on a helicopter.
	root.add_child(_box(Vector3(2.6, 1.2, 4.0), HOT, Vector3(0, 1.9, 0.8)))
	root.add_child(_cyl(0.5, 1.6, EXHAUST * 0.55, Vector3(1.2, 2.2, 2.6), Vector3(0, 0, deg_to_rad(90))))
	root.add_child(_cyl(0.5, 1.6, EXHAUST * 0.55, Vector3(-1.2, 2.2, 2.6), Vector3(0, 0, deg_to_rad(90))))
	# Skids.
	for side in [-1.0, 1.0]:
		root.add_child(_cyl(0.16, 7.0, COLD, Vector3(side * 1.6, -2.0, -0.5), Vector3(deg_to_rad(90), 0, 0)))
	# Spinning rotor.
	var hub := Node3D.new()
	hub.name = "Rotor"
	hub.position = Vector3(0, 2.8, 0.0)
	for i in 4:
		var blade := _box(Vector3(15.0, 0.12, 0.9), WARM * 0.8, Vector3.ZERO)
		blade.rotation = Vector3(0, deg_to_rad(i * 45.0), 0)
		hub.add_child(blade)
	root.add_child(hub)
	# Tail rotor.
	var trotor := Node3D.new()
	trotor.name = "TailRotor"
	trotor.position = Vector3(0.4, 2.0, 11.2)
	for i in 2:
		var b := _box(Vector3(0.12, 3.2, 0.5), WARM * 0.8, Vector3.ZERO)
		b.rotation = Vector3(0, 0, deg_to_rad(i * 90.0))
		trotor.add_child(b)
	root.add_child(trotor)
	return root


static func _drone() -> Node3D:
	var root := Node3D.new()
	root.add_child(_cyl(0.5, 4.5, COLD, Vector3.ZERO, Vector3(deg_to_rad(90), 0, 0), 0.3))
	root.add_child(_box(Vector3(6.5, 0.16, 1.1), COLD, Vector3(0, 0.1, 0.4)))
	root.add_child(_box(Vector3(2.0, 0.16, 0.9), COLD, Vector3(0, 0.0, 2.0)))
	root.add_child(_box(Vector3(0.14, 1.4, 1.0), COLD, Vector3(0, 0.7, 2.1)))
	root.add_child(_cyl(0.34, 1.2, HOT * 0.8, Vector3(0, 0.1, 2.5), Vector3(deg_to_rad(90), 0, 0)))
	root.add_child(_cyl(0.26, 1.6, EXHAUST * 0.35, Vector3(0, 0.1, 3.4), Vector3(deg_to_rad(90), 0, 0), 0.15))
	return root


static func _missile() -> Node3D:
	var root := Node3D.new()
	root.add_child(_cyl(0.38, 6.2, WARM, Vector3.ZERO, Vector3(deg_to_rad(90), 0, 0)))
	root.add_child(_cyl(0.38, 1.4, WARM * 1.5, Vector3(0, 0, -3.6), Vector3(deg_to_rad(-90), 0, 0), 0.04))
	for i in 4:
		var f := _box(Vector3(1.5, 0.1, 1.1), COLD, Vector3.ZERO)
		var pivot := Node3D.new()
		pivot.rotation = Vector3(0, 0, deg_to_rad(i * 90.0))
		f.position = Vector3(0.9, 0, 2.4)
		pivot.add_child(f)
		root.add_child(pivot)
	# Rocket / turbojet plume: the brightest thing in the sky.
	root.add_child(_cyl(0.3, 5.0, EXHAUST, Vector3(0, 0, 5.4), Vector3(deg_to_rad(90), 0, 0), 0.08))
	return root


static func _gunship() -> Node3D:
	var root := Node3D.new()
	# Slab-sided fictional gunship: armoured hull, sponsons, lift fans.
	root.add_child(_box(Vector3(9.0, 6.0, 30.0), COLD, Vector3.ZERO))
	root.add_child(_prism(Vector3(9.0, 6.0, 8.0), COLD * 1.1, Vector3(0, 0, -19.0),
			Vector3(deg_to_rad(-90), 0, 0)))
	root.add_child(_box(Vector3(6.0, 2.0, 5.0), WARM, Vector3(0, 2.0, -13.0)))
	for side in [-1.0, 1.0]:
		# Sponsons with weapon barrels.
		root.add_child(_box(Vector3(4.0, 2.4, 12.0), COLD, Vector3(side * 6.0, -1.0, -2.0)))
		for b in 3:
			root.add_child(_cyl(0.22, 6.0, WARM * 1.3,
					Vector3(side * (5.0 + b * 1.1), -1.2, -9.0), Vector3(deg_to_rad(90), 0, 0)))
		# Ducted lift fans, hot rims.
		root.add_child(_cyl(3.2, 1.6, HOT, Vector3(side * 8.0, 1.0, 6.0)))
		root.add_child(_cyl(2.6, 0.4, EXHAUST * 0.5, Vector3(side * 8.0, -0.2, 6.0)))
		# Main thrusters.
		root.add_child(_cyl(1.8, 4.0, HOT, Vector3(side * 3.0, 0.0, 15.0), Vector3(deg_to_rad(90), 0, 0)))
		root.add_child(_cyl(1.4, 6.0, EXHAUST, Vector3(side * 3.0, 0.0, 19.0),
				Vector3(deg_to_rad(90), 0, 0), 0.2))
	root.add_child(_box(Vector3(1.0, 7.0, 7.0), COLD, Vector3(0, 6.0, 12.0)))
	return root


static func _dropship() -> Node3D:
	var root := Node3D.new()
	root.add_child(_box(Vector3(7.0, 5.5, 18.0), COLD, Vector3.ZERO))
	root.add_child(_sph(3.0, WARM, Vector3(0, 0.4, -10.0)))
	for side in [-1.0, 1.0]:
		# Tilting nacelles.
		root.add_child(_box(Vector3(10.0, 0.7, 4.5), COLD, Vector3(side * 6.5, 2.2, 1.0)))
		root.add_child(_cyl(1.8, 5.0, HOT, Vector3(side * 10.0, 2.2, 1.0), Vector3(deg_to_rad(90), 0, 0)))
		root.add_child(_cyl(1.3, 4.0, EXHAUST * 0.8, Vector3(side * 10.0, 1.4, 3.6),
				Vector3(deg_to_rad(70), 0, 0), 0.2))
		root.add_child(_box(Vector3(0.6, 4.0, 4.0), COLD, Vector3(side * 3.0, 4.0, 8.0)))
	root.add_child(_box(Vector3(6.0, 0.6, 5.0), COLD, Vector3(0, -2.6, 6.0)))
	return root


static func _leviathan() -> Node3D:
	var root := Node3D.new()
	# Capital-ship-sized flyer. Long armoured spine with greebles and a
	# cluster of very hot drive bells at the stern.
	root.add_child(_box(Vector3(34.0, 16.0, 150.0), COLD, Vector3.ZERO))
	root.add_child(_prism(Vector3(34.0, 16.0, 40.0), COLD * 1.15, Vector3(0, 0, -95.0),
			Vector3(deg_to_rad(-90), 0, 0)))
	# Dorsal spine.
	root.add_child(_box(Vector3(10.0, 7.0, 110.0), COLD * 1.3, Vector3(0, 10.0, 5.0)))
	# Hangar bay mouth (warm).
	root.add_child(_box(Vector3(14.0, 5.0, 3.0), WARM * 1.4, Vector3(0, -6.0, -40.0)))
	# Greebles / sponsons.
	for i in 6:
		var z := -55.0 + i * 20.0
		for side in [-1.0, 1.0]:
			root.add_child(_box(Vector3(6.0, 5.0, 9.0), COLD * 1.2, Vector3(side * 18.0, -2.0, z)))
			root.add_child(_cyl(0.5, 9.0, WARM, Vector3(side * 20.0, 2.0, z),
					Vector3(deg_to_rad(90), 0, 0)))
	# Radiator fins - hot, and the intended weak point.
	for side in [-1.0, 1.0]:
		root.add_child(_box(Vector3(2.0, 22.0, 40.0), HOT * 0.85, Vector3(side * 19.0, 12.0, 30.0)))
	# Drive cluster.
	for i in 6:
		var a := TAU * float(i) / 6.0
		var p := Vector3(cos(a) * 11.0, sin(a) * 6.0, 78.0)
		root.add_child(_cyl(4.0, 8.0, HOT, p, Vector3(deg_to_rad(90), 0, 0)))
		root.add_child(_cyl(3.0, 16.0, EXHAUST, p + Vector3(0, 0, 11.0),
				Vector3(deg_to_rad(90), 0, 0), 0.2))
	# Bridge tower.
	root.add_child(_box(Vector3(12.0, 10.0, 14.0), COLD * 1.4, Vector3(0, 17.0, 40.0)))
	root.add_child(_box(Vector3(9.0, 2.0, 2.0), WARM * 1.6, Vector3(0, 19.0, 33.0)))
	return root


## Rigid airship carrier, 360 m long and 68 m across. Built at final size so
## the hitbox volumes and weak points in EnemyDB can use these coordinates
## directly.
##
## In thermal it reads in layers: a cool hull, warmer structural rings that
## band it, a lit gondola with a row of windows, four hot engine pods with
## plumes, and a glowing launch bay on the belly that is the obvious target.
const MS_R := 34.0     # hull radius
const MS_HALF := 180.0 # half length


static func _ms_radius_at(z: float) -> float:
	var k := clampf(z / MS_HALF, -1.0, 1.0)
	return MS_R * sqrt(maxf(1.0 - k * k, 0.0))


static func _mothership() -> Node3D:
	var root := Node3D.new()
	var hull_v := COLD * 1.2

	# Hull: a stretched sphere with enough segments to hold up at 3x zoom.
	var hull := SphereMesh.new()
	hull.radius = 1.0
	hull.height = 2.0
	hull.radial_segments = 24
	hull.rings = 14
	root.add_child(_mi(hull, hull_v, Vector3.ZERO, Vector3.ZERO, Vector3(MS_R, MS_R, MS_HALF)))

	# Structural rings: thin discs a metre proud of the hull everywhere.
	for z in [-150.0, -112.0, -74.0, -36.0, 2.0, 40.0, 78.0, 116.0, 152.0]:
		var rr: float = _ms_radius_at(z) + 1.0
		root.add_child(_cyl(rr, 3.0, WARM, Vector3(0, 0, z), Vector3(deg_to_rad(90), 0, 0), -1.0, 24))

	# Nose cap and dorsal running lights.
	root.add_child(_sph(5.0, WARM, Vector3(0, 0, -MS_HALF + 1.0)))
	for z in [-90.0, -30.0, 30.0, 90.0]:
		root.add_child(_box(Vector3(2.5, 2.0, 7.0), HOT * 0.8, Vector3(0, _ms_radius_at(z) + 0.6, z)))

	# Gondola / command deck under the forward hull, with a row of lit windows.
	root.add_child(_box(Vector3(16, 12, 86), WARM * 0.8, Vector3(0, -38, -40)))
	root.add_child(_sph(8.0, WARM, Vector3(0, -35, -84)))
	for i in 9:
		var z := -78.0 + i * 9.0
		root.add_child(_box(Vector3(0.6, 2.2, 4.5), HOT * 0.75, Vector3(8.3, -37, z)))
		root.add_child(_box(Vector3(0.6, 2.2, 4.5), HOT * 0.75, Vector3(-8.3, -37, z)))

	# Four engine pods on pylons. The hottest structure on the ship.
	for z in [-55.0, 60.0]:
		for side in [-1.0, 1.0]:
			var x: float = side * 50.0
			root.add_child(_box(Vector3(16, 3, 12), hull_v, Vector3(side * 38.0, -6, z)))
			root.add_child(_cyl(8.0, 32.0, HOT, Vector3(x, -6, z), Vector3(deg_to_rad(90), 0, 0), -1.0, 14))
			root.add_child(_cyl(6.0, 36.0, EXHAUST, Vector3(x, -6, z + 34.0),
					Vector3(deg_to_rad(90), 0, 0), 0.6, 14))

	# Cruciform tail.
	var tail_r := _ms_radius_at(150.0)
	root.add_child(_box(Vector3(3, 40, 48), hull_v, Vector3(0, tail_r + 20.0, 150)))
	root.add_child(_box(Vector3(3, 40, 48), hull_v, Vector3(0, -tail_r - 20.0, 150)))
	root.add_child(_box(Vector3(40, 3, 48), hull_v, Vector3(tail_r + 20.0, 0, 150)))
	root.add_child(_box(Vector3(40, 3, 48), hull_v, Vector3(-tail_r - 20.0, 0, 150)))

	# Launch bay: open doors on the belly, glowing. Craft drop out of here.
	root.add_child(_box(Vector3(22, 5, 70), HOT * 0.9, Vector3(0, -33.5, 70)))
	root.add_child(_box(Vector3(17, 1, 62), EXHAUST * 0.55, Vector3(0, -36.2, 70)))
	return root


## Orbital dreadnought, about 1.3 km from fork tips to drive plumes in model
## units. EnemyDB scales it 1.6x, so it is roughly 2 km long in the sky. The
## hitbox, weak points and bays in EnemyDB use these model coordinates.
##
## The silhouette is deliberately not a wedge: a stepped slab hull that gets
## heavier toward the stern, a forked bow with a hot emitter between the
## prongs, three collars the hull runs through, radiator wings, a tall sail
## and a block of six drive bells. Seen from below, the belly shows four lit
## hangar slots, which is where its craft come from.
static func _dreadnought() -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var dark := COLD * 1.0
	var hull := COLD * 1.3
	var light := COLD * 1.75

	# Three stepped hull blocks: [size, centre].
	var blocks := [
		[Vector3(100, 76, 290), Vector3(0, 0, -295)],   # fore
		[Vector3(160, 100, 350), Vector3(0, 0, 25)],    # mid
		[Vector3(220, 130, 360), Vector3(0, 0, 380)],   # stern
	]
	for b in blocks:
		var s: Vector3 = b[0]
		var c: Vector3 = b[1]
		root.add_child(_box(s, hull, c))
		# Shoulder chamfers along the top edges so the blocks aren't bricks.
		for side in [-1.0, 1.0]:
			root.add_child(_box(Vector3(s.x * 0.22, s.y * 0.22, s.z * 0.96), dark,
					c + Vector3(side * s.x * 0.42, s.y * 0.47, 0), Vector3(0, 0, side * 0.6)))
		# Side plating and running lights.
		var z0: float = c.z - s.z * 0.5 + 14.0
		var z1: float = c.z + s.z * 0.5 - 14.0
		var z := z0
		while z < z1:
			for side in [-1.0, 1.0]:
				var h := rng.randf_range(s.y * 0.2, s.y * 0.55)
				var v := dark if rng.randf() < 0.5 else light
				root.add_child(_box(Vector3(4, h, rng.randf_range(10, 22)), v,
						c + Vector3(side * (s.x * 0.5 + 2.0), rng.randf_range(-s.y * 0.25, s.y * 0.2), 0) + Vector3(0, 0, z - c.z)))
				if int(z) % 3 == 0:
					root.add_child(_box(Vector3(1.5, 2.5, 10), HOT * 0.7,
							Vector3(side * (s.x * 0.5 + 4.2), c.y + s.y * 0.28, z)))
			z += rng.randf_range(18.0, 30.0)
		# Belly plates, so the underside reads as structure from the deck.
		for i in int(s.z / 40.0):
			for j in 3:
				if rng.randf() < 0.35:
					continue
				var pz: float = c.z - s.z * 0.5 + 20.0 + float(i) * 40.0
				var px: float = (float(j) - 1.0) * s.x * 0.3
				root.add_child(_box(Vector3(s.x * 0.24, 3, rng.randf_range(20, 36)),
						dark if rng.randf() < 0.55 else light, Vector3(px, -s.y * 0.5 - 1.5, pz)))
		# Dorsal plates.
		for i in int(s.z / 50.0):
			var pz2: float = c.z - s.z * 0.5 + 25.0 + float(i) * 50.0
			root.add_child(_box(Vector3(s.x * 0.5, 4, rng.randf_range(18, 34)), light,
					Vector3(0, s.y * 0.5 + 2.0, pz2)))

	# Forked bow: two prongs with tapered tips, a crossbar and a hot emitter.
	for side in [-1.0, 1.0]:
		root.add_child(_box(Vector3(44, 56, 200), hull, Vector3(side * 62.0, 0, -500)))
		root.add_child(_prism(Vector3(44, 60, 56), hull, Vector3(side * 62.0, 0, -630),
				Vector3(deg_to_rad(-90), 0, 0)))
		root.add_child(_box(Vector3(46, 3, 150), light, Vector3(side * 62.0, -29.5, -500)))
		root.add_child(_box(Vector3(2, 6, 160), HOT * 0.75, Vector3(side * 62.0 + side * 22.5, 8, -500)))
	root.add_child(_box(Vector3(124, 32, 34), hull, Vector3(0, 0, -415)))
	root.add_child(_sph(18.0, HOT, Vector3(0, 0, -440)))
	root.add_child(_sph(10.0, EXHAUST * 0.8, Vector3(0, 0, -452)))
	for k in 3:
		root.add_child(_cyl(26.0 - k * 5.0, 2.0, WARM * 1.4, Vector3(0, 0, -470.0 - k * 22.0),
				Vector3(deg_to_rad(90), 0, 0), -1.0, 16))

	# Collars the hull runs through, held on spokes.
	var collars := [[-60.0, 105.0, 125.0], [60.0, 105.0, 125.0], [-260.0, 70.0, 86.0]]
	for col in collars:
		var t := TorusMesh.new()
		t.inner_radius = float(col[1])
		t.outer_radius = float(col[2])
		t.rings = 32
		t.ring_segments = 6
		root.add_child(_mi(t, WARM * 1.15, Vector3(0, 0, float(col[0])), Vector3(deg_to_rad(90), 0, 0)))
		var mid: float = (float(col[1]) + float(col[2])) * 0.5
		for k in 4:
			var a := TAU * (float(k) + 0.5) / 4.0
			var p := Vector3(cos(a), sin(a), 0) * mid * 0.8
			root.add_child(_box(Vector3(6, 6, 10), dark, Vector3(p.x, p.y, float(col[0])),
					Vector3(0, 0, a)))
		# Lit nodes around each collar.
		for k in 8:
			var a2 := TAU * float(k) / 8.0
			root.add_child(_box(Vector3(5, 5, 22), HOT * 0.9,
					Vector3(cos(a2) * mid, sin(a2) * mid, float(col[0]))))

	# Sail: tall command tower on the stern with a lit bridge.
	root.add_child(_box(Vector3(40, 110, 120), hull, Vector3(0, 120, 300)))
	root.add_child(_box(Vector3(70, 24, 52), light, Vector3(0, 185, 272)))
	root.add_child(_box(Vector3(72, 3, 2), HOT, Vector3(0, 188, 245.5)))
	root.add_child(_box(Vector3(72, 3, 2), HOT * 0.8, Vector3(0, 181, 245.5)))
	for side in [-1.0, 1.0]:
		root.add_child(_box(Vector3(2, 70, 4), HOT * 0.6, Vector3(side * 21.0, 110, 280)))
	root.add_child(_cyl(1.5, 60.0, WARM, Vector3(0, 225, 290)))

	# Radiator wings off the stern: thin, warm, ribbed.
	for side in [-1.0, 1.0]:
		root.add_child(_box(Vector3(120, 4, 170), WARM * 0.9, Vector3(side * 170.0, 20, 400)))
		for k in 6:
			root.add_child(_box(Vector3(118, 5, 3), HOT * 0.75,
					Vector3(side * 170.0, 20, 330.0 + k * 28.0)))
		root.add_child(_box(Vector3(10, 30, 60), dark, Vector3(side * 112.0, 20, 400)))

	# Hangar slots on the belly of the mid hull: the launch points.
	for hz in [-90.0, -10.0, 70.0, 150.0]:
		var y := -50.5
		root.add_child(_box(Vector3(70, 4, 50), HOT * 0.9, Vector3(0, y, hz)))
		root.add_child(_box(Vector3(56, 1, 40), EXHAUST * 0.55, Vector3(0, y - 2.2, hz)))

	# Drive block: six bells and their plumes.
	root.add_child(_box(Vector3(230, 120, 24), dark, Vector3(0, 0, 566)))
	for x in [-70.0, 0.0, 70.0]:
		for y2 in [-30.0, 30.0]:
			var p2 := Vector3(x, y2, 590)
			root.add_child(_cyl(20.0, 36.0, HOT, p2, Vector3(deg_to_rad(90), 0, 0), 28.0, 12))
			root.add_child(_cyl(20.0, 120.0, EXHAUST, p2 + Vector3(0, 0, 78), Vector3(deg_to_rad(90), 0, 0),
					6.0, 12))
	return root


static func _orb() -> Node3D:
	var root := Node3D.new()
	root.add_child(_sph(5.0, COLD * 1.4))
	root.add_child(_cyl(6.5, 1.2, WARM))
	root.add_child(_cyl(7.6, 0.4, HOT * 0.7))
	for i in 3:
		var a := TAU * float(i) / 3.0
		root.add_child(_sph(1.1, EXHAUST * 0.6, Vector3(cos(a) * 5.4, -2.6, sin(a) * 5.4)))
	return root


# ---------------------------------------------------------------------------
# The mount you are sitting in
# ---------------------------------------------------------------------------

## Barrel cluster + housing seen in the bottom of the sensor frame.
static func build_gun() -> Node3D:
	var root := Node3D.new()
	# Barrel cluster: six barrels around a common axis, pointing -Z.
	var cluster := Node3D.new()
	cluster.name = "BarrelCluster"
	for i in 6:
		var a := TAU * float(i) / 6.0
		var b := _cyl(0.05, 2.05, 0.30,
				Vector3(cos(a) * 0.115, sin(a) * 0.115, -1.15),
				Vector3(deg_to_rad(90), 0, 0))
		cluster.add_child(b)
	root.add_child(cluster)
	# Muzzle clamp + receiver.
	root.add_child(_cyl(0.16, 0.12, 0.38, Vector3(0, 0, -2.05), Vector3(deg_to_rad(90), 0, 0)))
	root.add_child(_cyl(0.20, 0.5, 0.34, Vector3(0, 0, -0.05), Vector3(deg_to_rad(90), 0, 0)))
	root.add_child(_box(Vector3(0.75, 0.55, 0.9), 0.30, Vector3(0, -0.12, 0.55)))
	# Ammo drum silhouette below.
	root.add_child(_cyl(0.6, 0.7, 0.26, Vector3(0, -0.72, 0.75)))
	return root


## Missile cell launcher, mounted on the yaw platform behind the sensor head -
## so a launch streaks up and over you from behind, the way a VLS does.
static func build_launcher() -> Node3D:
	var root := Node3D.new()
	root.add_child(_box(Vector3(2.2, 1.5, 1.6), 0.24, Vector3.ZERO))
	# Cell mouths, angled slightly forward.
	for col in 4:
		for row in 2:
			var p := Vector3(-0.72 + col * 0.48, 0.78, -0.36 + row * 0.62)
			root.add_child(_cyl(0.17, 0.12, 0.38, p))
			root.add_child(_cyl(0.13, 0.06, 0.16, p + Vector3(0, 0.05, 0)))
	root.add_child(_box(Vector3(2.4, 0.2, 1.8), 0.20, Vector3(0, -0.82, 0)))
	root.add_child(_box(Vector3(0.3, 1.1, 0.3), 0.18, Vector3(1.35, -0.3, 0)))
	root.add_child(_box(Vector3(0.3, 1.1, 0.3), 0.18, Vector3(-1.35, -0.3, 0)))
	return root


## A single interceptor, built facing -Z. Kept small and simple: at engagement
## range it is a few pixels, and the smoke trail carries the read.
static func build_missile_mesh() -> Mesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = 0.16
	c.height = 2.4
	c.radial_segments = 6
	c.rings = 1
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1, 1)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	c.material = m
	return c


## The mount's own radome, sat behind the sensor head.
static func build_radome() -> Node3D:
	var root := Node3D.new()
	root.add_child(_sph(1.25, 0.28, Vector3(0, 0.9, 0)))
	root.add_child(_cyl(1.3, 0.55, 0.24, Vector3(0, 0.15, 0)))
	root.add_child(_cyl(1.0, 1.4, 0.21, Vector3(0, -0.7, 0)))
	return root


## Static deck furniture. Everything here must stay clear of the sensor head,
## which sits at roughly y = 2.5 and yaws through the full 360 degrees - hence
## the low deck plate and the structures pushed well out to the edge.
static func build_deck() -> Node3D:
	var root := Node3D.new()
	# Mount pedestal, entirely below the sensor.
	root.add_child(_cyl(1.15, 1.6, 0.20, Vector3(0, -0.4, 0)))
	# Deck plate.
	root.add_child(_cyl(9.0, 0.5, 0.19, Vector3(0, -1.35, 0)))
	# Railing.
	for i in 32:
		var a := TAU * float(i) / 32.0
		root.add_child(_cyl(0.06, 1.1, 0.17, Vector3(cos(a) * 8.6, -0.6, sin(a) * 8.6)))
	root.add_child(_cyl(8.7, 0.07, 0.17, Vector3(0, -0.1, 0)))
	# Superstructure well out at the edge, for parallax as the mount slews.
	root.add_child(_box(Vector3(4.0, 2.6, 7.0), 0.21, Vector3(-14.0, -0.6, 7.0)))
	root.add_child(_box(Vector3(3.0, 4.0, 4.0), 0.21, Vector3(13.0, 0.2, -9.0)))
	root.add_child(_cyl(0.3, 14.0, 0.21, Vector3(15.0, 5.5, 10.0)))
	root.add_child(_box(Vector3(9.0, 1.4, 2.0), 0.21, Vector3(0, -1.0, -17.0)))
	return root
