extends Node
class_name BarrelHeat

const COLD_LEVEL := 0.3
const HOT_LEVEL := 0.95
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

var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	for barrel in turret.barrels.get_children():
		var mesh := barrel as MeshInstance3D
		if mesh != null:
			mesh.material_override = _material


func warning() -> bool:
	return heat >= WARNING_LEVEL and not turret.overheated


func _process(delta: float) -> void:
	if turret.firing:
		heat += heat_per_second * heat_scale * loadout.heat_scale * turret.spin * delta
	else:
		heat -= cooling_per_second * (1.0 + cold) * delta
	heat = clampf(heat, 0.0, 1.0)
	_update_icing(delta)
	if heat >= 1.0 and not turret.overheated:
		turret.set_overheated(true)
	elif heat <= RECOVER_LEVEL and turret.overheated:
		turret.set_overheated(false)
	var level := lerpf(COLD_LEVEL, HOT_LEVEL, heat)
	_material.albedo_color = Color(level, level, level, 1.0)


func _update_icing(delta: float) -> void:
	if turret.firing or heat > WARM_LEVEL or cold <= 0.0:
		icing -= thaw_per_second * turret.spin * delta
	else:
		icing += icing_per_second * cold * delta
	icing = clampf(icing, 0.0, 1.0)
	turret.spinup_scale = 1.0 + icing * FROZEN_SPINUP
