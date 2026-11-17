extends Node
class_name FireCutout

# Stops the gun when its bore points into the ship's own structure. Every
# mesh on the ship gets an exact collision copy, already placed and scaled, on
# a layer nothing else uses, and a ray along the bore tests against them.

const REACH: float = 300.0
const STRUCTURE_LAYER: int = 1 << 9

@export var turret: Turret
@export var ship: Node3D
@export var exempt: Array[Node3D] = []

var _surveyed: bool = false


func _physics_process(_delta: float) -> void:
	if not _surveyed:
		_survey()
	var origin := turret.muzzle.global_position
	var bore := -turret.muzzle.global_basis.z
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + bore * REACH, STRUCTURE_LAYER)
	ray.hit_back_faces = true
	turret.cut_out = not turret.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _survey() -> void:
	_surveyed = true
	var body := StaticBody3D.new()
	body.collision_layer = STRUCTURE_LAYER
	body.collision_mask = 0
	ship.add_child(body)
	var to_ship := ship.global_transform.affine_inverse()
	for part in ship.find_children("*", "MeshInstance3D", true, false):
		var mesh := part as MeshInstance3D
		if mesh.mesh == null or _is_exempt(mesh):
			continue
		var faces := mesh.mesh.get_faces()
		var placed := to_ship * mesh.global_transform
		for i in faces.size():
			faces[i] = placed * faces[i]
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision = true
		var holder := CollisionShape3D.new()
		holder.shape = shape
		body.add_child(holder)


func _is_exempt(part: Node3D) -> bool:
	for node in exempt:
		if node == part or node.is_ancestor_of(part):
			return true
	return false
