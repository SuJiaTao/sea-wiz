extends RefCounted
class_name Ballistics

const HALF := 0.5
const EPSILON := 0.0001


static func intercept_time(offset: Vector3, velocity: Vector3, speed: float) -> float:
	var a := velocity.length_squared() - speed * speed
	var b := 2.0 * offset.dot(velocity)
	var c := offset.length_squared()
	if absf(a) < EPSILON:
		return -c / b if absf(b) >= EPSILON else -1.0
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return -1.0
	var root := sqrt(discriminant)
	var first := (-b - root) / (2.0 * a)
	var second := (-b + root) / (2.0 * a)
	if first > 0.0 and second > 0.0:
		return minf(first, second)
	return maxf(first, second)


static func aim_point(position: Vector3, velocity: Vector3, time: float) -> Vector3:
	return (
		position + velocity * time
		+ Vector3.UP * HALF * BulletProjectile.GRAVITY * time * time
	)
