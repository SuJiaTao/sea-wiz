extends AbstractEnemy
class_name WreckEnemy

const RADIUS_PER_SIZE: float = 5.0
const SAVE_LABEL := "WRECK SAVE"

@export var bonus_reach: float = 450.0
@export var close_bonus: float = 3.0

var _wreck: WreckEffect
var _ship_position := Vector3.ZERO

@onready var _hurtbox: Area3D = $Hurtbox
@onready var _shape: CollisionShape3D = $Hurtbox/BodyShape


func follow(wreck: WreckEffect, ship_position: Vector3) -> void:
	_wreck = wreck
	_ship_position = ship_position
	hud_radius = wreck.size * RADIUS_PER_SIZE


func score_points() -> int:
	var offset := global_position - _ship_position
	var closeness := 1.0 - clampf(Vector2(offset.x, offset.z).length() / bonus_reach, 0.0, 1.0)
	return roundi(score_value * (1.0 + close_bonus * closeness))


func score_label() -> String:
	return SAVE_LABEL


func _create() -> void:
	(_shape.shape as SphereShape3D).radius = hud_radius
	_hurtbox.collision_layer = COLLISION_LAYER


func _on_think(_delta: float) -> void:
	if _wreck == null or _wreck._finished:
		request_destroy()
		return
	global_position = _wreck.position
	velocity = _wreck.velocity


func _on_killed() -> void:
	_wreck.shatter()


func _on_destroy() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.collision_layer = 0
