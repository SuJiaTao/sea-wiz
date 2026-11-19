extends Control
class_name BackupReticle

# The etched cross on the backup sight glass: all that is left to aim with
# when the ship loses power.

const ARM: float = 14.0
const GAP: float = 4.0
const RING: float = 26.0
const WIDTH: float = 1.0
const COLOUR := Color(1.0, 1.0, 1.0, 0.85)


func _draw() -> void:
	var centre := size * 0.5
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(centre + direction * GAP, centre + direction * (GAP + ARM), COLOUR, WIDTH)
	draw_arc(centre, RING, 0.0, TAU, 48, COLOUR, WIDTH)
