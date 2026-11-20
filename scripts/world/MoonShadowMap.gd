extends Node
class_name MoonShadowMap

# Bakes the ship's moon shadow once, at the start: a camera looks at the ship
# from the moon and records its outline. Splashes, ripples, rain and the sea's
# rain pattering then look the map up instead of working shadows out live.

const SHADOW_LAYER: int = 1 << 19
const CAMERA_DISTANCE: float = 800.0
const PARAMETERS := {
	"map": &"moon_shadow_map",
	"origin": &"moon_shadow_origin",
	"right": &"moon_shadow_right",
	"up": &"moon_shadow_up",
	"extent": &"moon_shadow_extent",
}

@export var ship: Node3D
@export var moonlight: DirectionalLight3D
## Everything that should dim in the ship's moon shadow.
@export var receivers: Array[GeometryInstance3D] = []
@export var extent: float = 260.0
@export var resolution: int = 512


func _ready() -> void:
	_bake.call_deferred()


func _bake() -> void:
	for part in ship.find_children("*", "GeometryInstance3D", true, false):
		(part as GeometryInstance3D).layers |= SHADOW_LAYER
	var toward_moon := moonlight.global_basis.z.normalized()
	var view := SubViewport.new()
	view.size = Vector2i(resolution, resolution)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var eye := Camera3D.new()
	eye.projection = Camera3D.PROJECTION_ORTHOGONAL
	eye.size = extent
	eye.far = CAMERA_DISTANCE * 2.0
	eye.cull_mask = SHADOW_LAYER
	var clear := Environment.new()
	clear.background_mode = Environment.BG_CLEAR_COLOR
	eye.environment = clear
	view.add_child(eye)
	add_child(view)
	var centre := ship.global_position
	eye.look_at_from_position(centre + toward_moon * CAMERA_DISTANCE, centre, _up_for(toward_moon))
	eye.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var outline := ImageTexture.create_from_image(view.get_texture().get_image())
	var values := {
		"map": outline,
		"origin": centre,
		"right": eye.global_basis.x,
		"up": eye.global_basis.y,
		"extent": extent,
	}
	for receiver in receivers:
		var material := _material_of(receiver)
		if material == null:
			continue
		for key: String in PARAMETERS:
			material.set_shader_parameter(PARAMETERS[key], values[key])
	view.queue_free()


func _up_for(direction: Vector3) -> Vector3:
	return Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.99 else Vector3.UP


func _material_of(receiver: GeometryInstance3D) -> ShaderMaterial:
	if receiver.material_override is ShaderMaterial:
		return receiver.material_override as ShaderMaterial
	var mesh: Mesh = null
	if receiver is MeshInstance3D:
		mesh = (receiver as MeshInstance3D).mesh
	elif receiver is MultiMeshInstance3D and (receiver as MultiMeshInstance3D).multimesh != null:
		mesh = (receiver as MultiMeshInstance3D).multimesh.mesh
	if mesh == null:
		return null
	return mesh.surface_get_material(0) as ShaderMaterial
