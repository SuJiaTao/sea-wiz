@abstract
extends Resource
class_name EnemyCounter

@export var answers: Array[StringName] = []
@export var warning: String = ""
@export var tag: String = ""


func provoked_by(loadout: ShipLoadout) -> bool:
	for mount in answers:
		if loadout.is_fitted(mount):
			return true
	return false


@abstract
func apply_to(enemy: AbstractEnemy) -> void
