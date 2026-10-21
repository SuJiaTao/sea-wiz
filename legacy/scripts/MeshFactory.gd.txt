extends RefCounted
class_name MeshFactory

const COLD := 0.30
const WARM := 0.55
const HOT := 0.95
const EXHAUST := 2.60

const ENEMY_SCENES := {
	"drone": preload("res://scenes/enemy/DroneVisuals.tscn"),
	"jet": preload("res://scenes/enemy/JetVisuals.tscn"),
	"heavy_jet": preload("res://scenes/enemy/HeavyJetVisuals.tscn"),
	"helo": preload("res://scenes/enemy/HeloVisuals.tscn"),
	"missile": preload("res://scenes/enemy/MissileVisuals.tscn"),
	"gunship": preload("res://scenes/enemy/GunshipVisuals.tscn"),
	"dropship": preload("res://scenes/enemy/DropshipVisuals.tscn"),
	"leviathan": preload("res://scenes/enemy/LeviathanVisuals.tscn"),
	"mothership": preload("res://scenes/enemy/MothershipVisuals.tscn"),
	"dreadnought": preload("res://scenes/enemy/DreadnoughtVisuals.tscn"),
	"orb": preload("res://scenes/enemy/OrbVisuals.tscn"),
}

const GUN_SCENE := preload("res://scenes/turret/Gun.tscn")
const LAUNCHER_SCENE := preload("res://scenes/turret/Launcher.tscn")
const RADOME_SCENE := preload("res://scenes/turret/Radome.tscn")
const DECK_SCENE := preload("res://scenes/world/Deck.tscn")
const INTERCEPTOR_SCENE := preload("res://scenes/ballistics/Interceptor.tscn")

static var _mat_cache: Dictionary = {}


static func mat(value: float) -> StandardMaterial3D:
	var key := snappedf(value, 0.01)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(value, value, value, 1.0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_mat_cache[key] = material
	return material


static func build(kind: String) -> Node3D:
	var scene: PackedScene = ENEMY_SCENES.get(kind, ENEMY_SCENES["drone"])
	return scene.instantiate() as Node3D


static func build_gun() -> Node3D:
	return GUN_SCENE.instantiate() as Node3D


static func build_launcher() -> Node3D:
	return LAUNCHER_SCENE.instantiate() as Node3D


static func build_radome() -> Node3D:
	return RADOME_SCENE.instantiate() as Node3D


static func build_deck() -> Node3D:
	return DECK_SCENE.instantiate() as Node3D


static func build_missile_mesh() -> Mesh:
	var instance := INTERCEPTOR_SCENE.instantiate() as MeshInstance3D
	var mesh := instance.mesh
	instance.free()
	return mesh
