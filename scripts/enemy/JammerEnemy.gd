extends HeloEnemy
class_name JammerEnemy

@export_range(0.0, 1.0) var jam_strength: float = 0.6
@export var jam_range: float = 3000.0


func jam_at(point: Vector3) -> float:
	var reach := 1.0 - global_position.distance_to(point) / jam_range
	return jam_strength * clampf(reach, 0.0, 1.0)
