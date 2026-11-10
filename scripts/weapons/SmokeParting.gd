extends Node
class_name SmokeParting

@export var turret: Turret
@export var smoke_batches: Array[ParticleBatch] = []
@export var reach: float = 1200.0
@export var radius: float = 6.0
@export var push_speed: float = 5.0
@export var thinning: float = 0.04
@export var parts_per_second: float = 10.0

var _since_last: float = 0.0
var _origin: Vector3
var _direction: Vector3
var _firing_line: bool = false


func _ready() -> void:
	turret.fired.connect(_on_fired)


func _process(delta: float) -> void:
	_since_last += delta
	if not _firing_line or _since_last < 1.0 / parts_per_second:
		return
	_since_last = 0.0
	_firing_line = false
	var end := _origin + _direction * reach
	for batch in smoke_batches:
		batch.part_along(_origin, end, radius, push_speed, thinning)


func _on_fired(origin: Vector3, velocity: Vector3) -> void:
	_origin = origin
	_direction = velocity.normalized()
	_firing_line = true
