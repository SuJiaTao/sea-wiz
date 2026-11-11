extends EnemyCounter
class_name StealthCounter

@export var radar_reach: float = 1200.0


func apply_to(enemy: AbstractEnemy) -> void:
	if enemy.contact_kind == AbstractEnemy.ContactKind.AIRCRAFT:
		enemy.radar_reach = minf(enemy.radar_reach, radar_reach)
