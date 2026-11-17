extends Node
class_name BarrelHeat

const HOT_GLOW: float = 0.3
const GLOW_CURVE: float = 2.0
const GLOW := "glow"
const WARNING_LEVEL := 0.75
const RECOVER_LEVEL := 0.35
const WARM_LEVEL := 0.2
const FROZEN_SPINUP := 5.0

@export var turret: Turret
@export var loadout: ShipLoadout
@export var heat_per_second: float = 0.11
@export var cooling_per_second: float = 0.2
@export var icing_per_second: float = 0.06
@export var thaw_per_second: float = 0.5

var heat: float = 0.0
var icing: float = 0.0
var heat_scale: float = 1.0
var cold: float = 0.0
var wet: float = 0.0

var _barrels: Array[MeshInstance3D] = []


func _ready() -> void:
	for barrel in turret.barrels.get_children():
		if barrel is MeshInstance3D:
			_barrels.append(barrel)


func warning() -> bool:
	return heat >= WARNING_LEVEL and not turret.overheated


func _process(delta: float) -> void:
	if turret.shooting():
		heat += heat_per_second * heat_scale * loadout.heat_scale * turret.spin * delta
	else:
		heat -= cooling_per_second * (1.0 + cold + wet) * delta
	heat = clampf(heat, 0.0, 1.0)
	_update_icing(delta)
	if heat >= 1.0 and not turret.overheated:
		turret.set_overheated(true)
	elif heat <= RECOVER_LEVEL and turret.overheated:
		turret.set_overheated(false)
	var glow := pow(heat, GLOW_CURVE) * HOT_GLOW
	for barrel in _barrels:
		barrel.set_instance_shader_parameter(GLOW, glow)


func _update_icing(delta: float) -> void:
	if turret.shooting() or heat > WARM_LEVEL or cold <= 0.0:
		icing -= thaw_per_second * turret.spin * delta
	else:
		icing += icing_per_second * cold * delta
	icing = clampf(icing, 0.0, 1.0)
	turret.spinup_scale = 1.0 + icing * FROZEN_SPINUP
