extends RefCounted
class_name DoomFire

const MAX_HEAT: int = 36
const SPREAD_MASK: int = 3
const SPREAD_CENTRE: int = 1
const DECAY_MASK: int = 1

var width: int
var height: int
var cells := PackedByteArray()


func _init(grid_width: int, grid_height: int) -> void:
	width = grid_width
	height = grid_height
	cells.resize(width * height)
	cells.fill(0)
	_ignite()


func step(lean: float) -> void:
	var lean_chance := absf(lean)
	var lean_direction := int(signf(lean))
	for y in range(1, height):
		var row := y * width
		var above := row - width
		for x in width:
			var heat := cells[row + x]
			if heat == 0:
				cells[above + x] = 0
				continue
			# Fabien Sanglard's PSX Doom fire: carry heat up one row, shifted by
			# 1 - spread columns, cooling by one on odd spreads.
			var spread := randi() & SPREAD_MASK
			var shift := SPREAD_CENTRE - spread
			if randf() < lean_chance:
				shift += lean_direction
			cells[above + posmod(x + shift, width)] = heat - (spread & DECAY_MASK)


func _ignite() -> void:
	var source_row := (height - 1) * width
	for x in width:
		cells[source_row + x] = MAX_HEAT
