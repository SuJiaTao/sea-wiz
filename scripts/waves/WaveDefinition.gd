extends Resource
class_name WaveDefinition

@export var title: String = ""
@export var spawns: Array[WaveSpawn] = []
@export var if_engaged: WaveDefinition
@export var if_ignored: WaveDefinition
## The ship loses power partway into this wave: no picture, no HUD, no radar.
@export var blackout: bool = false
## Fitted to the ship as this wave is announced.
@export var unlocks: Array[Upgrade] = []
## The ship's decks catch fire as this wave starts.
@export var ignite_ship: bool = false
## Least time between enemy missile launches in this wave, so early waves
## never send a whole salvo at once.
@export var missile_gap: float = 0.0
## Share of runs in which the gap is lifted and they may all fire at once.
@export_range(0.0, 1.0) var salvo_chance: float = 0.0
