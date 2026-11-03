extends StrikeAircraft
class_name StealthBomberEnemy

@export var bomb_bay: BombBay
@export var release_distance: float = 1100.0

@onready var _hurtbox: Area3D = $Hurtbox


func _on_flight_created() -> void:
	_hurtbox.collision_layer = COLLISION_LAYER


func _on_flight_step(delta: float) -> void:
	if _leg != Leg.RUN_IN or bomb_bay == null:
		return
	var offset := target_position - global_position
	if Vector2(offset.x, offset.z).length() > release_distance:
		return
	bomb_bay.release(self, delta, target_position, _flat(velocity))


func _on_destroy() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.collision_layer = 0
