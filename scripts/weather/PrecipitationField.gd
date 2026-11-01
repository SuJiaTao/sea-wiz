extends MultiMeshInstance3D
class_name PrecipitationField

const CENTRE := "centre"
const BOX_SIZE := "box_size"
const UNCULLED := AABB(Vector3(-1.0e5, -1.0e5, -1.0e5), Vector3(2.0e5, 2.0e5, 2.0e5))

@export var turret: Turret
@export var particle_mesh: Mesh
@export var capacity: int = 6000
@export var box := Vector3(80.0, 50.0, 80.0)

var _material: ShaderMaterial


func _ready() -> void:
	_material = particle_mesh.surface_get_material(0) as ShaderMaterial
	_material.set_shader_parameter(BOX_SIZE, box)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = particle_mesh
	multimesh.instance_count = capacity
	for index in capacity:
		var spot := Vector3(randf(), randf(), randf()) * box
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, spot))
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = UNCULLED


func set_amount(count: float) -> void:
	multimesh.visible_instance_count = clampi(int(count), 0, capacity)
	visible = multimesh.visible_instance_count > 0


func _process(_delta: float) -> void:
	if visible:
		_material.set_shader_parameter(CENTRE, turret.camera.global_position)
