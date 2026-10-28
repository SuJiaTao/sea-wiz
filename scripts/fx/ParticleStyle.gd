extends Resource
class_name ParticleStyle

@export var mesh: Mesh
@export var lifetime := Vector2(1.0, 2.0)
@export var start_size := Vector2(1.0, 1.0)
@export var gravity: float = 0.0
@export var buoyancy: float = 0.0
@export var drag: float = 0.0
@export_range(0.0, 1.0) var wind_factor: float = 1.0


func random_lifetime() -> float:
	return randf_range(lifetime.x, lifetime.y)


func random_size() -> float:
	return randf_range(start_size.x, start_size.y)


func vertical_acceleration() -> float:
	return buoyancy - gravity
