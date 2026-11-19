extends DirectionalLight3D
class_name MoonLight

# Moonlight that casts shadows, aimed from wherever the sky paints the moon
# and dimmed as the storm ceiling closes over it.

const BEARING := "moon_bearing_deg"
const ELEVATION := "moon_elevation_deg"
const OVERCAST := "overcast"
const OVERCAST_BLOCK: float = 0.45

@export var environment: WorldEnvironment

var _full_energy: float = 1.0


func _ready() -> void:
	_full_energy = light_energy
	var bearing := deg_to_rad(_sky().get_shader_parameter(BEARING))
	var elevation := deg_to_rad(_sky().get_shader_parameter(ELEVATION))
	var toward := Vector3(sin(bearing) * cos(elevation), sin(elevation), -cos(bearing) * cos(elevation))
	basis = Basis.looking_at(-toward, Vector3.UP)


func _process(_delta: float) -> void:
	var overcast: float = _sky().get_shader_parameter(OVERCAST)
	light_energy = _full_energy * (1.0 - overcast * OVERCAST_BLOCK)
	visible = light_energy > 0.0


func _sky() -> ShaderMaterial:
	return environment.environment.sky.sky_material as ShaderMaterial
