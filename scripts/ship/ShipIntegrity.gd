extends Node
class_name ShipIntegrity

signal damaged(amount: float, from_position: Vector3)

@export var capacity: float = 100.0

var damage: float = 0.0

var flooding: float:
	get:
		return clampf(damage / capacity, 0.0, 1.0)


func take_hit(amount: float, from_position: Vector3) -> void:
	if amount <= 0.0:
		return
	damage = minf(damage + amount, capacity)
	damaged.emit(amount, from_position)
