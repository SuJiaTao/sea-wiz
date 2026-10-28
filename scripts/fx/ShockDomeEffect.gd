extends AbstractEffect
class_name ShockDomeEffect

const RADIUS_PER_SIZE: float = 26.0
const GROWTH_TIME: float = 0.14
const LINGER: float = 0.35
const FADE_TIME: float = 1.1
const FADE := "fade"

var _position: Vector3
var _radius: float
var _dome: MeshInstance3D
var _material: ShaderMaterial


func _init(at: Vector3, size: float) -> void:
	_position = at
	_radius = size * RADIUS_PER_SIZE


func _on_spawn(effects: EffectManager) -> void:
	_dome = MeshInstance3D.new()
	_dome.mesh = effects.shock_dome_mesh
	_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = (effects.shock_dome_mesh.surface_get_material(0) as ShaderMaterial).duplicate()
	_dome.material_override = _material
	effects.add_child(_dome)
	_dome.global_position = _position
	_dome.scale = Vector3.ONE * 0.01


func _on_step(_effects: EffectManager, _delta: float) -> void:
	var grown := 1.0 - exp(-age / GROWTH_TIME)
	_dome.scale = Vector3.ONE * maxf(_radius * grown, 0.01)
	_material.set_shader_parameter(FADE, clampf((age - LINGER) / FADE_TIME, 0.0, 1.0))
	if age >= LINGER + FADE_TIME:
		finish()


func _on_finish(_effects: EffectManager) -> void:
	if is_instance_valid(_dome):
		_dome.queue_free()
