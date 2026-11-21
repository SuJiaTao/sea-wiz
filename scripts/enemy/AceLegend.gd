class_name AceLegend

# What the game remembers about the ace across waves: if he broke off
# wounded and got away, he is due back, as hurt as he left.

static var escaped: bool = false
static var hp_left: float = 0.0


static func reset() -> void:
	escaped = false
	hp_left = 0.0


static func record_escape(hp: float) -> void:
	escaped = true
	hp_left = hp


## The returning ace takes up his old wounds; returns the hp he comes back with.
static func come_back(full_hp: float) -> float:
	var hp := hp_left if escaped else full_hp
	escaped = false
	hp_left = 0.0
	return hp
