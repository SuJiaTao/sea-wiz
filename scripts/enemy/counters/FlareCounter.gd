extends EnemyCounter
class_name FlareCounter

@export var extra_salvos: int = 2


func apply_to(enemy: AbstractEnemy) -> void:
	enemy.countermeasures_enabled = true
	var flyer := enemy as FlyingEnemy
	if flyer != null and flyer.flares != null:
		flyer.flares.add_salvos(extra_salvos)
