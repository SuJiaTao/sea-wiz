class_name GunnerView

# Where the CIWS gunner is looking, and whether the gun is firing, as a pilot
# watching the ship would read it from the turret and the tracers.

static var eye := Vector3.ZERO
static var aim := Vector3.FORWARD
static var shooting: bool = false


static func track(from: Vector3, direction: Vector3, is_shooting: bool) -> void:
	eye = from
	aim = direction.normalized()
	shooting = is_shooting


## How far off the gunner's line of sight a point is, in degrees.
static func off_aim_deg(point: Vector3) -> float:
	return rad_to_deg(aim.angle_to(point - eye))


## Which way round the ship to go to get further from the gunner's sight
## line: 1 or -1 about the up axis.
static func away_side(point: Vector3) -> float:
	var side := signf(aim.cross(point - eye).y)
	return side if side != 0.0 else 1.0
