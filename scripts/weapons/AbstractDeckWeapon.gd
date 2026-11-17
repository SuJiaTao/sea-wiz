@abstract
extends Node
class_name AbstractDeckWeapon

const GRAVITY: float = 9.81

@export var fitting: StringName

var on_target: bool = false

var _enabled: bool = true


func set_enabled(value: bool) -> void:
	_enabled = value


func trigger() -> void:
	if _enabled:
		_trigger()


func restock() -> void:
	pass


## 0 straight after a shot, 1 when it can fire again.
func readiness() -> float:
	return 1.0


## Where the next shot would land, for the HUD marker; INF when it has none.
func fall_of_shot() -> Vector3:
	return Vector3.INF


## Raises the aim so a shell fired from origin at speed drops onto point.
static func with_drop(origin: Vector3, point: Vector3, speed: float) -> Vector3:
	var flight := origin.distance_to(point) / speed
	return point + Vector3.UP * (0.5 * GRAVITY * flight * flight)


@abstract
func _trigger() -> void
