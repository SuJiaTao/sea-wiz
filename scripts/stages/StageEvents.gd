extends Node
class_name StageEvents

# What a wave changes about the ship itself: new gear fitted as it is
# announced, and the decks set alight as it starts.

const IGNITE_STRENGTH: float = 0.7

@export var waves: WaveOrchestrator
@export var fires: DeckFires


func _ready() -> void:
	waves.level_prepared.connect(_on_level_prepared)
	waves.level_started.connect(_on_level_started)


func _on_level_prepared(_number: int, _title: String) -> void:
	for upgrade in waves.current_level.unlocks:
		if upgrade.can_accumulate_still():
			upgrade.apply_upgrade()


func _on_level_started(_number: int, _title: String) -> void:
	if waves.current_level.ignite_ship:
		fires.ignite_all(IGNITE_STRENGTH)
