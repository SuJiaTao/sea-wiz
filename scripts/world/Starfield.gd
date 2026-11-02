extends Node3D
class_name Starfield

@export var star_mesh: Mesh
@export var count: int = 30
@export var radius: float = 5500.0
@export var elevation_deg := Vector2(8.0, 82.0)
@export var brightness := Vector2(0.35, 0.85)
@export var layout_seed: int = 7


func _ready() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = layout_seed
	for index in count:
		var bearing := random.randf() * TAU
		var elevation := deg_to_rad(random.randf_range(elevation_deg.x, elevation_deg.y))
		var star := MeshInstance3D.new()
		star.mesh = star_mesh
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		star.position = Vector3(
			sin(bearing) * cos(elevation), sin(elevation), -cos(bearing) * cos(elevation)
		) * radius
		star.set_instance_shader_parameter("brightness", random.randf_range(brightness.x, brightness.y))
		star.set_instance_shader_parameter("twinkle", 1.0)
		add_child(star)
