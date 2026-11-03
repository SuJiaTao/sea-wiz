extends Node
class_name BombBay

@export var bomb_scene: PackedScene
@export var bombs: int = 6
@export var interval: float = 0.6
@export var spread_along: float = 90.0
@export var spread_across: float = 25.0

var _left: int = 0
var _cooldown: float = 0.0


func _ready() -> void:
	_left = bombs


func is_empty() -> bool:
	return _left <= 0


func release(
	carrier: AbstractEnemy,
	delta: float,
	aim_point: Vector3,
	track: Vector3
) -> void:
	_cooldown -= delta
	if _left <= 0 or _cooldown > 0.0 or bomb_scene == null:
		return
	_cooldown = interval
	_left -= 1
	var bomb := bomb_scene.instantiate() as FlyingEnemy
	var across := track.cross(Vector3.UP)
	var step := float(bombs - _left) / float(bombs) - 0.5
	bomb.target_position = (
		aim_point + track * step * spread_along * 2.0
		+ across * randf_range(-spread_across, spread_across)
	)
	bomb.velocity = carrier.velocity
	carrier.deployed.emit(bomb, Transform3D(Basis.IDENTITY, carrier.global_position))
