@abstract
extends Node3D
class_name AbstractEnemy

enum State { CREATING, ALIVE, DEAD, DESTROYED }

const COLLISION_LAYER: int = 1 << 1

@export var max_hp: float = 20.0

var hp: float = 0.0
var velocity := Vector3.ZERO

var alive: bool:
	get:
		return (_state == State.ALIVE)

var _state: State = State.CREATING
var _destroy_requested: bool = false


func take_damage(amount: float, world_point: Vector3) -> void:
	if not alive or amount <= 0.0 or hp <= 0.0:
		return
	var applied := minf(amount, hp)
	hp -= applied
	_on_damage(applied, world_point)


func request_destroy() -> void:
	if _state == State.DESTROYED:
		return
	_destroy_requested = true


func _activate() -> void:
	hp = max_hp
	_create()
	if _state != State.DESTROYED and not _destroy_requested:
		_state = State.ALIVE


func _destroy() -> void:
	if _state == State.DESTROYED:
		return
	_state = State.DESTROYED
	_on_destroy()


func _exit_tree() -> void:
	_destroy()


func _create() -> void:
	pass


@abstract
func _on_think(delta: float) -> void


func _on_damage(_amount: float, _world_point: Vector3) -> void:
	pass


func _on_killed() -> void:
	pass


func _on_destroy() -> void:
	pass
