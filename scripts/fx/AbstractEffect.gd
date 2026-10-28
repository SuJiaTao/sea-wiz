@abstract
extends RefCounted
class_name AbstractEffect

var age: float = 0.0

var _finished: bool = false


func finish() -> void:
	_finished = true


@abstract
func _on_spawn(effects: EffectManager) -> void


func _on_step(_effects: EffectManager, _delta: float) -> void:
	pass


func _on_finish(_effects: EffectManager) -> void:
	pass
