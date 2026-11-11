extends RefCounted
class_name OrbitSteering

const RADIUS_GAIN: float = 250.0
const ALTITUDE_GAIN: float = 120.0


static func direction(position: Vector3, centre: Vector3, radius: float, altitude: float) -> Vector3:
	var outward := Vector3(position.x - centre.x, 0.0, position.z - centre.z)
	var reach := outward.length()
	outward = outward.normalized()
	var along := outward.cross(Vector3.UP)
	var inward := outward * (reach - radius) / -RADIUS_GAIN
	var climb := Vector3.UP * (altitude - position.y) / ALTITUDE_GAIN
	return (along + inward + climb).normalized()
