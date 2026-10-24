shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// Cold sea surface with faint moving clutter. Deliberately very dark so that,
// after the thermal posterise pass, it reads as an almost-black plane with a
// crisp horizon line.

uniform float base_level : hint_range(0.0, 0.5) = 0.08;
uniform float clutter_level : hint_range(0.0, 0.5) = 0.02;
uniform float clutter_scale = 0.006;
uniform float clutter_speed = 0.09;
uniform float falloff = 520.0;
uniform float moon_bearing_deg : hint_range(0.0, 360.0) = 140.0;
uniform float moon_elevation_deg : hint_range(0.0, 90.0) = 22.0;
uniform float glitter : hint_range(0.0, 4.0) = 0.8;
uniform float glitter_sharpness : hint_range(1.0, 400.0) = 120.0;
uniform float ripple_scale = 0.35;
uniform float ripple_slope : hint_range(0.0, 1.0) = 0.22;
uniform float ripple_speed = 0.6;

const float DISPLAY_GAMMA = 2.2;

float hash21(vec2 p) {
	p = fract(p * vec2(233.34, 851.73));
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

const float SLOPE_STEP = 0.5;

varying vec3 world_pos;

vec3 moon_direction() {
	float bearing = radians(moon_bearing_deg);
	float elevation = radians(moon_elevation_deg);
	return vec3(sin(bearing) * cos(elevation), sin(elevation), -cos(bearing) * cos(elevation));
}

float ripples(vec2 p) {
	vec2 drift = vec2(TIME * ripple_speed, -TIME * ripple_speed * 0.7);
	return value_noise(p + drift) * 0.6 + value_noise(p * 2.3 - drift) * 0.4;
}

float moon_glitter(vec3 view_ray) {
	vec2 p = world_pos.xz * ripple_scale;
	float centre = ripples(p);
	float dx = ripples(p + vec2(SLOPE_STEP, 0.0)) - centre;
	float dz = ripples(p + vec2(0.0, SLOPE_STEP)) - centre;
	vec3 normal = normalize(vec3(-dx * ripple_slope / SLOPE_STEP, 1.0, -dz * ripple_slope / SLOPE_STEP));
	float facing = max(dot(reflect(view_ray, normal), moon_direction()), 0.0);
	return pow(facing, glitter_sharpness) * glitter;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * clutter_scale;
	float n = value_noise(p + vec2(TIME * clutter_speed, TIME * clutter_speed * 0.6));
	n = n * 0.7 + value_noise(p * 2.7 - vec2(TIME * clutter_speed * 0.4, 0.0)) * 0.3;

	// Fade clutter out with distance so the far field is flat and cold.
	float dist = length(world_pos.xz);
	float fade = clamp(1.0 - dist / falloff, 0.0, 1.0);
	fade = fade * fade;

	float v = base_level + n * clutter_level * fade;
	v += moon_glitter(normalize(world_pos - CAMERA_POSITION_WORLD));
	ALBEDO = vec3(pow(v, DISPLAY_GAMMA));
}
