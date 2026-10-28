extends RefCounted
class_name DoomFire

const MAX_HEAT: int = 36
const SPREAD_MASK: int = 3
const SPREAD_CENTRE: int = 1
const DECAY_MASK: int = 1

var width: int
var height: int
var cooling: float
var cells := PackedByteArray()


func _init(grid_width: int, grid_height: int, cooling_chance: float) -> void:
	width = grid_width
	height = grid_height
	cooling = cooling_chance
	cells.resize(width * height)
	cells.fill(0)


func feed(source: PackedByteArray) -> void:
	var source_row := (height - 1) * width
	for x in width:
		cells[source_row + x] = source[x]


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
			var decay := spread & DECAY_MASK
			if decay > 0 and randf() > cooling:
				decay = 0
			cells[above + posmod(x + shift, width)] = heat - decay
