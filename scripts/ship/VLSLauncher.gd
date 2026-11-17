extends Node
class_name VLSLauncher
## Drives the forward missile launcher in destroyer_v13.glb.
## Model nodes: VLS (hide this until the upgrade) > VLS_Cell_00..31 (hatch lids, hinged on their aft edge)
## and VLS_Uptake_0..3 (one exhaust hatch per 8-cell module; cells 0-7 are module 0, 8-15 module 1, ...).
## Add this as a child of the imported ship. Call launch() to fire from the next free cell:
## the lid and its module's exhaust hatch swing open, cell_ready fires when it's fully open
## (spawn the missile and the fire/smoke there), then both close again.

signal cell_ready(cell: int, launch_position: Vector3, up: Vector3)

@export var installed := false:            ## false hides the whole launcher until the upgrade
	set(v):
		installed = v
		if _vls:
			_vls.visible = v
@export var lid_open_deg := 100.0
@export var uptake_open_deg := 95.0
@export var open_time := 0.35              ## seconds for a lid to swing fully open
@export var hold_time := 1.2               ## seconds it stays open after cell_ready
@export var close_time := 0.6

const CELLS_PER_MODULE := 8
enum { CLOSED, OPENING, HOLD, CLOSING }

var _vls: Node3D
var _cells: Array[Node3D] = []
var _uptakes: Array[Node3D] = []
var _cell_rest: Array[Basis] = []
var _uptake_rest: Array[Basis] = []
var _state: Array[int] = []
var _t: Array[float] = []                  ## 0 = closed, 1 = fully open
var _hold: Array[float] = []
var _uptake_t: Array[float] = []
var _next := 0


func _ready() -> void:
	_vls = get_parent().find_child("VLS", true, false) as Node3D
	var i := 0
	while true:
		var c := _vls.find_child("VLS_Cell_%02d" % i, true, false) as Node3D
		if c == null:
			break
		_cells.append(c)
		_cell_rest.append(c.basis)
		_state.append(CLOSED)
		_t.append(0.0)
		_hold.append(0.0)
		i += 1
	var m := 0
	while true:
		var u := _vls.find_child("VLS_Uptake_%d" % m, true, false) as Node3D
		if u == null:
			break
		_uptakes.append(u)
		_uptake_rest.append(u.basis)
		_uptake_t.append(0.0)
		m += 1
	_vls.visible = installed


func cell_count() -> int:
	return _cells.size()


## Opens the next closed cell (or a specific one). Returns the cell index, or -1 if none is free.
func launch(cell := -1) -> int:
	if not installed:
		return -1
	if cell < 0:
		for k in _cells.size():
			var c := (_next + k) % _cells.size()
			if _state[c] == CLOSED:
				cell = c
				break
	if cell < 0 or _state[cell] != CLOSED:
		return -1
	_next = (cell + 1) % _cells.size()
	_state[cell] = OPENING
	return cell


func is_cell_open(cell: int) -> bool:
	return _state[cell] == HOLD


## Centre of the cell opening, a little above the deck, in world space.
func cell_world_position(cell: int) -> Vector3:
	var hinge := _cells[cell]
	var parent := hinge.get_parent() as Node3D
	return parent.global_transform * (hinge.position + Vector3(0, 0.1, -0.36))


func _process(delta: float) -> void:
	var module_busy := []
	module_busy.resize(_uptakes.size())
	module_busy.fill(false)
	for c in _cells.size():
		match _state[c]:
			OPENING:
				_t[c] = minf(1.0, _t[c] + delta / open_time)
				if _t[c] >= 1.0:
					_state[c] = HOLD
					_hold[c] = hold_time
					var up := (_vls.global_transform.basis.y).normalized()
					cell_ready.emit(c, cell_world_position(c), up)
			HOLD:
				_hold[c] -= delta
				if _hold[c] <= 0.0:
					_state[c] = CLOSING
			CLOSING:
				_t[c] = maxf(0.0, _t[c] - delta / close_time)
				if _t[c] <= 0.0:
					_state[c] = CLOSED
		if _state[c] != CLOSED:
			module_busy[c / CELLS_PER_MODULE] = true
		var ease_t := ease(_t[c], -2.0)
		_cells[c].basis = _cell_rest[c] * Basis(Vector3.RIGHT, deg_to_rad(lid_open_deg) * ease_t)
	for m in _uptakes.size():
		var target := 1.0 if module_busy[m] else 0.0
		var speed := 1.0 / (open_time if target > _uptake_t[m] else close_time)
		_uptake_t[m] = move_toward(_uptake_t[m], target, speed * delta)
		_uptakes[m].basis = _uptake_rest[m] * Basis(Vector3.RIGHT, deg_to_rad(uptake_open_deg) * ease(_uptake_t[m], -2.0))
