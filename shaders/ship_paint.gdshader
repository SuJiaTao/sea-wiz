shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

// Haze grey paint under a night sky: faces turned to the moon catch it,
// faces turned down or away fall into shade.

uniform float tone : hint_range(0.0, 1.0) = 0.35;
uniform float sky_light : hint_range(0.0, 1.0) = 0.55;
uniform float moon_light : hint_range(0.0, 1.0) = 0.45;
uniform float underside : hint_range(0.0, 1.0) = 0.35;
uniform float moon_bearing_deg : hint_range(0.0, 360.0) = 140.0;
uniform float moon_elevation_deg : hint_range(0.0, 90.0) = 22.0;

const float DISPLAY_GAMMA = 2.2;

vec3 moon_direction() {
	float bearing = radians(moon_bearing_deg);
	float elevation = radians(moon_elevation_deg);
	return vec3(sin(bearing) * cos(elevation), sin(elevation), -cos(bearing) * cos(elevation));
}

void fragment() {
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (!FRONT_FACING) {
		normal = -normal;
	}
	float sky = mix(underside, 1.0, normal.y * 0.5 + 0.5);
	float moon = max(dot(normal, moon_direction()), 0.0);
	float level = tone * (sky_light * sky + moon_light * moon);
	ALBEDO = vec3(pow(level, DISPLAY_GAMMA));
}
