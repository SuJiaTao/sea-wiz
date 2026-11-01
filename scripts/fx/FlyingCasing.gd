extends RefCounted
class_name FlyingCasing

var slot: int
var position: Vector3
var velocity: Vector3
var spin: Vector3
var orientation := Basis.IDENTITY


func _init(instance_slot: int, start: Vector3, launch: Vector3, tumble: Vector3) -> void:
	slot = instance_slot
	position = start
	velocity = launch
	spin = tumble


func fly(delta: float, gravity: float) -> void:
	velocity.y -= gravity * delta
	position += velocity * delta
	var turn := spin.length() * delta
	if turn > 0.0:
		orientation = Basis(spin.normalized(), turn) * orientation
