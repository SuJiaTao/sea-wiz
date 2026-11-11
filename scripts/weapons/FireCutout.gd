extends Node
class_name FireCutout

const REACH: float = 300.0

@export var turret: Turret
@export var ship: Node3D
@export var exempt: Array[Node3D] = []

var _structure: Array[AABB] = []


func _physics_process(_delta: float) -> void:
	if _structure.is_empty():
		_survey()
	var to_ship := ship.global_transform.affine_inverse()
	var origin := to_ship * turret.muzzle.global_position
	var bore := (to_ship.basis * -turret.muzzle.global_basis.z).normalized()
	turret.cut_out = _blocked(origin, bore)


func _survey() -> void:
	var from_ship := ship.global_transform.affine_inverse()
	for part in ship.find_children("*", "MeshInstance3D", true, false):
		var mesh := part as MeshInstance3D
		if mesh.mesh == null or _is_exempt(mesh):
			continue
		_structure.append(from_ship * mesh.global_transform * mesh.get_aabb())


func _is_exempt(part: Node3D) -> bool:
	for node in exempt:
		if node == part or node.is_ancestor_of(part):
			return true
	return false


func _blocked(origin: Vector3, bore: Vector3) -> bool:
	for box in _structure:
		if box.has_point(origin):
			continue
		var hit: Variant = box.intersects_ray(origin, bore)
		if hit != null and origin.distance_to(hit) <= REACH:
			return true
	return false
