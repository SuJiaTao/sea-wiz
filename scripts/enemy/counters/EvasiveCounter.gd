extends EnemyCounter
class_name EvasiveCounter

@export_range(0.0, 1.0) var jink_strength: float = 0.6


func apply_to(enemy: AbstractEnemy) -> void:
	var flyer := enemy as FlyingEnemy
	if flyer != null and enemy.contact_kind == AbstractEnemy.ContactKind.AIRCRAFT:
		flyer.jink_strength = jink_strength
