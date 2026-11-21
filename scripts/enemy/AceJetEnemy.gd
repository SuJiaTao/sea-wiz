extends JetEnemy
class_name AceJetEnemy

# A rare, very good pilot. He flies the same jet within the same limits as
# everyone else, but flies it well: inside our gun's reach he never holds a
# straight line, the moment rounds start striking him he breaks hard out of
# the stream, he answers a missile early with a long string of flares, and
# he likes to duck behind the bridge and come back out where you did not
# expect him.

## Inside this range of the ship he weaves the whole time.
@export var weave_range: float = 2200.0
@export var weave_strength: float = 0.55
## A break out of the gun stream lasts this long, then he can be caught again.
@export var gun_break_time: float = 1.6


func _on_flight_step(delta: float) -> void:
	super(delta)
	var offset := global_position - target_position
	jink_strength = weave_strength if Vector2(offset.x, offset.z).length() < weave_range else 0.0


func _on_damage(amount: float, world_point: Vector3) -> void:
	super(amount, world_point)
	if _break_remaining > 0.0:
		return
	# The rounds come from the ship: turn across the line of fire, not along it.
	_break_remaining = gun_break_time
	_break_from = target_position
