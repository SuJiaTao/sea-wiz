extends Node
class_name BlastFeel

const SOUND_SPEED: float = 343.0

@export var effects: EffectManager
@export var turret: Turret
@export var boom: AudioStreamPlayer
@export var felt_range: float = 3000.0
@export var impulse_per_size: float = 3.0
@export var quietest_db: float = -18.0


func _ready() -> void:
	effects.shockwave.connect(_on_shockwave)


func _on_shockwave(at: Vector3, size: float) -> void:
	var distance := at.distance_to(turret.global_position)
	var nearness := 1.0 - clampf(distance / felt_range, 0.0, 1.0)
	if nearness <= 0.0:
		return
	get_tree().create_timer(distance / SOUND_SPEED, false).timeout.connect(_arrive.bind(size, nearness))


func _arrive(size: float, nearness: float) -> void:
	turret.add_impulse(impulse_per_size * size * nearness)
	boom.volume_db = lerpf(quietest_db, 0.0, nearness)
	boom.play()
