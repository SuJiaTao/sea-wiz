extends Node
class_name BarrelHeat

const COLD_LEVEL := 0.3
const HOT_LEVEL := 0.95

@export var turret: Turret
@export var heat_per_second: float = 0.35
@export var cooling_per_second: float = 0.12

var heat: float = 0.0

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


func _process(delta: float) -> void:
	if turret.firing:
		heat = minf(heat + heat_per_second * delta, 1.0)
	else:
		heat = maxf(heat - cooling_per_second * delta, 0.0)
	var level := lerpf(COLD_LEVEL, HOT_LEVEL, heat)
	_material.albedo_color = Color(level, level, level, 1.0)
