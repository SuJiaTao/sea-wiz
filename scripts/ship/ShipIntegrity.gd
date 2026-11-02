extends Node
class_name ShipIntegrity

signal damaged(amount: float, from_position: Vector3)
signal repaired(damage_left_fraction: float)

@export var capacity: float = 100.0
@export var repair_per_wave: float = 35.0

var damage: float = 0.0

var flooding: float:
	get:
		return clampf(damage / capacity, 0.0, 1.0)


func take_hit(amount: float, from_position: Vector3) -> void:
	if amount <= 0.0:
		return
	damage = minf(damage + amount, capacity)
	damaged.emit(amount, from_position)


func repair(amount: float) -> void:
	if amount <= 0.0 or damage <= 0.0:
		return
	var before := damage
	damage = maxf(damage - amount, 0.0)
	repaired.emit(damage / before)
