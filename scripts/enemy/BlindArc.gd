class_name BlindArc

# The slice of sky behind the bridge that the CIWS cannot reach. Waves never
# open from it, strike aircraft swing out of it before they attack, and
# nothing fires, drops or launches from inside it.

const HALF_ANGLE_DEG: float = 40.0
const SWING_MARGIN_DEG: float = 10.0

static var center := Vector3.ZERO
static var stern := Vector3.BACK


static func track(ship: Node3D) -> void:
	center = ship.global_position
	stern = _flat(ship.global_basis.z)


static func contains(point: Vector3) -> bool:
	var from_ship := _flat(point - center)
	return from_ship.dot(stern) > cos(deg_to_rad(HALF_ANGLE_DEG))


static func open_bearing(random_share: float) -> float:
	var stern_angle := atan2(stern.z, stern.x)
	var half := deg_to_rad(HALF_ANGLE_DEG)
	return stern_angle + half + random_share * (TAU - half * 2.0)


## Which side of the arc a point is on: 1 or -1.
static func side_of(point: Vector3) -> float:
	var side := signf(stern.cross(_flat(point - center)).y)
	return side if side != 0.0 else 1.0


## Where to head to leave the arc, by the edge on the given side, or the
## nearer edge when no side is given.
static func way_out(point: Vector3, side: float = 0.0) -> Vector3:
	var from_ship := point - center
	var flat := Vector2(from_ship.x, from_ship.z)
	if side == 0.0:
		side = side_of(point)
	var swing := deg_to_rad(HALF_ANGLE_DEG + SWING_MARGIN_DEG) * side
	return center + stern.rotated(Vector3.UP, swing) * flat.length()


static func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z).normalized()
