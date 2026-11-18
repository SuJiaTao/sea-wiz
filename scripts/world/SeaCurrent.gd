class_name SeaCurrent

# Which way, and how fast, the sea's waves run on the surface. Anything that
# floats or lands on the water (rings, spray, burning fuel, falling rain) drifts
# with it so it moves together with the sea.

const WIND := "wind_bearing_deg"
const DEFAULT_WIND_DEG: float = 180.0
## Matches the swell speed in sea.gdshader.
const SWELL_SPEED: float = 4.0


static func velocity(sea_material: ShaderMaterial, speed: float = SWELL_SPEED) -> Vector3:
	if sea_material == null:
		return Vector3.ZERO
	var wind: Variant = sea_material.get_shader_parameter(WIND)
	var bearing := deg_to_rad(wind if wind != null else DEFAULT_WIND_DEG)
	return Vector3(sin(bearing), 0.0, -cos(bearing)) * speed
