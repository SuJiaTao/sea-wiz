extends Resource
class_name Formation

@export var slots: Array[Vector3] = []
@export var break_turns_deg: Array[float] = []
@export var break_range: float = 900.0
@export var break_time: float = 3.0


func break_turn_for(slot: int) -> float:
	if slot < 0 or slot >= break_turns_deg.size():
		return 0.0
	return deg_to_rad(break_turns_deg[slot])
