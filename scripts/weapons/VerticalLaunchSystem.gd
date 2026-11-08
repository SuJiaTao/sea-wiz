extends Node3D
class_name VerticalLaunchSystem

const LID_CLOSED := 0.0
const LID_OPEN := deg_to_rad(-115.0)
const EXIT_HEIGHT := 1.2

@export var open_speed: float = 14.0
@export var close_speed: float = 2.5
@export var hold_open: float = 1.8
@export var exhaust_puffs: int = 36
@export var exhaust_speed := Vector2(3.0, 11.0)

var _cells: Array[Node3D] = []
var _open_left: Array[float] = []
var _next: int = 0


func _ready() -> void:
	for child in get_children():
		if child is Node3D:
			_cells.append(child)
			_open_left.append(0.0)


func launch_point(smoke: ParticleBatch) -> Vector3:
	var cell := _cells[_next]
	_open_left[_next] = hold_open
	_next = (_next + 1) % _cells.size()
	var exit := cell.global_position + Vector3.UP * EXIT_HEIGHT
	if smoke != null:
		smoke.burst(exit, exhaust_puffs, exhaust_speed)
	return exit


func _process(delta: float) -> void:
	for index in _cells.size():
		_open_left[index] = maxf(_open_left[index] - delta, 0.0)
		var lid := _cells[index].get_child(0) as Node3D
		var opening := _open_left[index] > 0.0
		var target := LID_OPEN if opening else LID_CLOSED
		var speed := open_speed if opening else close_speed
		lid.rotation.x = move_toward(lid.rotation.x, target, speed * delta)
