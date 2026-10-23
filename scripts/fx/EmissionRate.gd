extends RefCounted
class_name EmissionRate

var _owed: float = 0.0


func due(per_second: float, delta: float) -> int:
	_owed += per_second * delta
	var count := int(_owed)
	_owed -= count
	return count
