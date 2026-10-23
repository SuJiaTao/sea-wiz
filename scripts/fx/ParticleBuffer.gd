extends RefCounted
class_name ParticleBuffer

var count: int = 0
var positions := PackedVector3Array()
var velocities := PackedVector3Array()
var ages := PackedFloat32Array()
var lifetimes := PackedFloat32Array()
var sizes := PackedFloat32Array()
var seeds := PackedFloat32Array()


func _init(capacity: int) -> void:
	positions.resize(capacity)
	velocities.resize(capacity)
	ages.resize(capacity)
	lifetimes.resize(capacity)
	sizes.resize(capacity)
	seeds.resize(capacity)


func is_full() -> bool:
	return count >= positions.size()


func add(position: Vector3, velocity: Vector3, lifetime: float, size: float) -> void:
	if is_full():
		return
	positions[count] = position
	velocities[count] = velocity
	ages[count] = 0.0
	lifetimes[count] = lifetime
	sizes[count] = size
	seeds[count] = randf()
	count += 1


func advance(delta: float, acceleration: Vector3, carried_by: Vector3, drag: float) -> void:
	var pull := clampf(drag * delta, 0.0, 1.0)
	var index := 0
	while index < count:
		ages[index] += delta
		if ages[index] >= lifetimes[index]:
			_remove(index)
			continue
		var velocity := velocities[index] + acceleration * delta
		velocity += (carried_by - velocity) * pull
		velocities[index] = velocity
		positions[index] += velocity * delta
		index += 1


func clear() -> void:
	count = 0


func _remove(index: int) -> void:
	count -= 1
	positions[index] = positions[count]
	velocities[index] = velocities[count]
	ages[index] = ages[count]
	lifetimes[index] = lifetimes[count]
	sizes[index] = sizes[count]
	seeds[index] = seeds[count]
