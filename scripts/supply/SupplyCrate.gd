extends AbstractEnemy
class_name SupplyCrate

signal recovered

const SWAY_RATE: float = 0.9
const SWAY_DEG: float = 9.0
const STROBE_PERIOD: float = 1.2
const STROBE_ON: float = 0.12
const ARRIVAL_RADIUS: float = 14.0

@export var strobe: Node3D

@onready var _hurtbox: Area3D = $Hurtbox

var landing := Vector3.ZERO
var descent_time: float = 40.0

var _age: float = 0.0


func _create() -> void:
	velocity = (landing - global_position) / descent_time
	_hurtbox.collision_layer = COLLISION_LAYER


func _on_think(delta: float) -> void:
	_age += delta
	global_position += velocity * delta
	if is_instance_valid(visuals):
		visuals.rotation.z = deg_to_rad(SWAY_DEG) * sin(_age * SWAY_RATE)
	strobe.visible = fmod(_age, STROBE_PERIOD) < STROBE_ON
	if global_position.distance_to(landing) <= ARRIVAL_RADIUS or _age >= descent_time:
		recovered.emit()
		request_destroy()


func _on_destroy() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.collision_layer = 0
