class_name LaunchSpacing

# Keeps enemy missile launches apart in time. Early waves set a gap so a
# whole formation cannot ripple its missiles off at once; a pilot who is not
# clear to launch keeps coming in and waits his turn.

static var gap: float = 0.0
static var _wait: float = 0.0


static func tick(delta: float) -> void:
	_wait = maxf(_wait - delta, 0.0)


static func clear() -> bool:
	return _wait <= 0.0


static func note() -> void:
	_wait = gap


static func reset(seconds: float) -> void:
	gap = seconds
	_wait = 0.0
