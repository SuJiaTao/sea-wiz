extends Node
class_name RadarJamming

@export var radar: SearchRadar
@export var enemies: EnemyManager

var level: float = 0.0
var strongest_source: AbstractEnemy


func _physics_process(_delta: float) -> void:
	var clear := 1.0
	var strongest := 0.0
	strongest_source = null
	for enemy in enemies.live_enemies():
		var jam := clampf(enemy.jam_at(radar.antenna.global_position), 0.0, 1.0)
		clear *= 1.0 - jam
		if jam > strongest:
			strongest = jam
			strongest_source = enemy
	level = 1.0 - clear
	radar.jam = level
