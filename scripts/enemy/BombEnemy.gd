extends AbstractEnemy
class_name BombEnemy

const GRAVITY: float = 9.81
const DECK_HEIGHT: float = 12.0
const SHIP_REACH: float = 45.0

@export var damage: float = 16.0
@export var target_position := Vector3.ZERO

@onready var _hurtbox: Area3D = $Hurtbox


func _create() -> void:
	_hurtbox.collision_layer = COLLISION_LAYER


func _on_think(delta: float) -> void:
	velocity += Vector3.DOWN * GRAVITY * delta
	global_position += velocity * delta
	if velocity.length_squared() > 0.0:
		look_at(global_position + velocity, Vector3.UP)
	var offset := global_position - target_position
	var over_ship := Vector2(offset.x, offset.z).length() <= SHIP_REACH
	if over_ship and global_position.y <= target_position.y + DECK_HEIGHT:
		reached_target.emit(damage)
		request_destroy()
	elif global_position.y <= target_position.y:
		missed.emit(global_position)
		request_destroy()


func _on_destroy() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.collision_layer = 0
