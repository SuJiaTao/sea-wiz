extends MultiMeshInstance3D
class_name ProjectileBatch

@export var batch_mesh: Mesh
@export var capacity: int = 900
var sensor: Camera3D
@export var near_cull: float = 0.0
@export var zoom_near_cull: float = 0.0

var _projectiles: Array[AbstractProjectile] = []


func _ready() -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = batch_mesh
	multimesh.instance_count = capacity
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))


func can_register() -> bool:
	return is_node_ready() and _projectiles.size() < capacity


func register(projectile: AbstractProjectile) -> void:
	assert(can_register())
	assert(not _projectiles.has(projectile))
	_projectiles.append(projectile)


func unregister(projectile: AbstractProjectile) -> void:
	var index := _projectiles.find(projectile)
	if index < 0:
		return
	var last := _projectiles.size() - 1
	_projectiles[index] = _projectiles[last]
	_projectiles.pop_back()
	multimesh.visible_instance_count = _projectiles.size()


func _process(_delta: float) -> void:
	var inverse := global_transform.affine_inverse()
	var cull := near_cull
	var has_sensor := is_instance_valid(sensor)
	if has_sensor and sensor.fov < 32.0:
		cull = zoom_near_cull
	multimesh.visible_instance_count = _projectiles.size()
	for index in _projectiles.size():
		var projectile := _projectiles[index]
		var instance_transform := inverse * projectile.visual_transform()
		var color := projectile.visual_color()
		if has_sensor and projectile.position.distance_squared_to(
			sensor.global_position
		) < cull * cull:
			instance_transform.basis = Basis.from_scale(Vector3.ZERO)
			color = Color(0, 0, 0, 0)
		multimesh.set_instance_transform(index, instance_transform)
		multimesh.set_instance_color(index, color)


func _exit_tree() -> void:
	_projectiles.clear()


static func make_material(transparent: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.disable_receive_shadows = true
	return material
