extends Node
class_name DeckGunTurret
## Drives one turret in the destroyer model: the twin gun (node_prefix "DeckGun"), the front gun ("FrontGun"),
## or a dome laser ("LaserP" port, "LaserS" starboard; set recoil_distance to 0 for lasers).
## Node chain in the model: <prefix>_Mount > <prefix>_Turret (turns left/right)
## > <prefix>_Elevation (raises the barrel) > <prefix>_Barrel (slides back on recoil).
## Traverse limits are measured from the way the mount faces (side guns face outboard).
## Add this as a child of the imported ship (the paths fill themselves in if left empty),
## then call aim_at(world_point) every frame and fire() when a shell goes out.

@export var node_prefix := "DeckGun"
@export var installed := true:             ## false hides this weapon (for upgrades that pop in)
	set(v):
		installed = v
		if _turret:
			(_turret.get_parent() as Node3D).visible = v
@export var turret_path: NodePath
@export var elevation_path: NodePath
@export var barrel_path: NodePath

@export var traverse_speed_deg := 40.0      ## how fast it turns left/right
@export var elevation_speed_deg := 25.0     ## how fast the barrel raises/lowers
@export var traverse_limit_deg := 150.0     ## each side of straight ahead (keeps it off the bridge)
@export var min_elevation_deg := -5.0
@export var max_elevation_deg := 65.0
@export var recoil_distance := 0.7          ## metres the barrel slides back when firing
@export var recoil_return_time := 0.4       ## seconds to run back out
@export var on_target_tolerance_deg := 1.5

const PARK_REACH := 2000.0

var _turret: Node3D
var _elevation: Node3D
var _barrel: Node3D
var _target := Vector3.ZERO
var _has_target := false
var _barrel_rest_z := 0.0


func _ready() -> void:
	_turret = _find(turret_path, node_prefix + "_Turret")
	_elevation = _find(elevation_path, node_prefix + "_Elevation")
	_barrel = _find(barrel_path, node_prefix + "_Barrel")
	_barrel_rest_z = _barrel.position.z
	(_turret.get_parent() as Node3D).visible = installed


func _find(path: NodePath, node_name: String) -> Node3D:
	if not path.is_empty():
		return get_node(path) as Node3D
	return get_parent().find_child(node_name, true, false) as Node3D


func aim_at(world_point: Vector3) -> void:
	_target = world_point
	_has_target = true


func clear_target() -> void:
	_has_target = false


func fire() -> void:
	_barrel.position.z = _barrel_rest_z + recoil_distance


func is_on_target() -> bool:
	if not _has_target:
		return false
	var want := _wanted_angles()
	var tol := deg_to_rad(on_target_tolerance_deg)
	return absf(wrapf(want.x - _turret.rotation.y, -PI, PI)) < tol and absf(want.y - _elevation.rotation.x) < tol


func muzzle_direction() -> Vector3:
	return -_barrel.global_transform.basis.z


## A point given in the barrel's own frame, in world space (muzzles, lens).
func barrel_point(local_point: Vector3) -> Vector3:
	return _barrel.global_transform * local_point


## Swings back to face straight ahead of the ship.
func park() -> void:
	var ship := get_parent() as Node3D
	aim_at(_turret.global_position - ship.global_basis.z * PARK_REACH)


func _process(delta: float) -> void:
	if _has_target:
		var want := _wanted_angles()
		var yaw_step := deg_to_rad(traverse_speed_deg) * delta
		var yaw_diff := wrapf(want.x - _turret.rotation.y, -PI, PI)
		_turret.rotation.y += clampf(yaw_diff, -yaw_step, yaw_step)
		var pitch_step := deg_to_rad(elevation_speed_deg) * delta
		_elevation.rotation.x = move_toward(_elevation.rotation.x, want.y, pitch_step)
	_barrel.position.z = move_toward(_barrel.position.z, _barrel_rest_z, recoil_distance / recoil_return_time * delta)


## x = wanted turret yaw, y = wanted barrel elevation (radians)
func _wanted_angles() -> Vector2:
	var mount := _turret.get_parent() as Node3D
	var p := mount.global_transform.affine_inverse() * _target
	var yaw := atan2(-p.x, -p.z)
	var limit := deg_to_rad(traverse_limit_deg)
	yaw = clampf(yaw, -limit, limit)
	# elevation measured from the trunnion, in the turret's frame once it faces the target
	var turned := Transform3D(Basis(Vector3.UP, yaw), _turret.position)
	var q := (turned * Transform3D(Basis(), _elevation.position)).affine_inverse() * p
	var pitch := atan2(q.y, -q.z)
	pitch = clampf(pitch, deg_to_rad(min_elevation_deg), deg_to_rad(max_elevation_deg))
	return Vector2(yaw, pitch)
