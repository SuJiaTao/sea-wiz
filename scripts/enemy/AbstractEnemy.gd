@abstract
extends Node3D
class_name AbstractEnemy

signal damaged(amount: float, world_point: Vector3)
signal reached_target(damage: float)
signal countermeasures_released(flares: Array[DecoyFlare])

enum State { CREATING, ALIVE, DEAD, DESTROYED }
enum ContactKind { AIRCRAFT, MISSILE }

const COLLISION_LAYER: int = 1 << 1

@export var max_hp: float = 20.0
@export var display_name: String = "CONTACT"
@export_range(0.1, 100.0) var hud_radius: float = 5.0
@export var visuals: Node3D
@export var contact_kind: ContactKind = ContactKind.AIRCRAFT

var hp: float = 0.0
var velocity := Vector3.ZERO
var countermeasures_enabled: bool = true

var alive: bool:
	get:
		return (_state == State.ALIVE)

var _state: State = State.CREATING
var _destroy_requested: bool = false
var _damage_source: DamageSource


func take_damage(
	amount: float,
	world_point: Vector3,
	weapon_source: DamageSource = null
) -> void:
	if not alive or amount <= 0.0 or hp <= 0.0:
		return
	var applied := minf(amount, hp)
	hp -= applied
	if hp <= 0.0:
		_damage_source = weapon_source
	_on_damage(applied, world_point)
	damaged.emit(applied, world_point)


func detach_visuals() -> Node3D:
	if not is_instance_valid(visuals):
		return null
	var detached := visuals
	var world_transform := detached.global_transform
	detached.get_parent().remove_child(detached)
	detached.transform = world_transform
	visuals = null
	return detached


func evade_missile(_missile_position: Vector3) -> DecoyFlare:
	return null


func request_destroy() -> void:
	if _state == State.DESTROYED:
		return
	_destroy_requested = true


func _activate() -> void:
	_damage_source = null
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
