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
uniform float roughness : hint_range(0.0, 1.0) = 0.0;
uniform float swell_wavelength = 140.0;
uniform float swell_speed = 9.0;
uniform float swell_level : hint_range(0.0, 0.3) = 0.04;
uniform float whitecap_level : hint_range(0.0, 1.0) = 0.16;
uniform float foam_scale = 0.22;
uniform float storm_falloff = 1600.0;
uniform float storm_slope = 2.5;
uniform float lightning_flash : hint_range(0.0, 2.0) = 0.0;
uniform float lightning_reflection : hint_range(0.0, 1.0) = 0.3;

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
	float slope = ripple_slope * (1.0 + roughness * storm_slope);
	vec3 normal = normalize(vec3(-dx * slope / SLOPE_STEP, 1.0, -dz * slope / SLOPE_STEP));
	float facing = max(dot(reflect(view_ray, normal), moon_direction()), 0.0);
	return pow(facing, glitter_sharpness) * glitter;
}

float swell(vec2 xz, vec2 heading, float wavelength) {
	return 0.5 + 0.5 * sin((dot(xz, heading) - TIME * swell_speed) * TAU / wavelength);
}

float rough_water(vec2 xz) {
	float waves = swell(xz, vec2(0.8, 0.6), swell_wavelength) * 0.6
		+ swell(xz, vec2(-0.5, 0.87), swell_wavelength * 0.62) * 0.4;
	float foam = value_noise(xz * foam_scale + vec2(TIME * 0.3, 0.0))
		* value_noise(xz * foam_scale * 2.4 - vec2(0.0, TIME * 0.2));
	float crest = smoothstep(0.7, 0.95, waves) * smoothstep(0.3, 0.55, foam);
	float fade = clamp(1.0 - length(xz) / storm_falloff, 0.0, 1.0);
	return ((waves - 0.5) * swell_level + crest * whitecap_level) * fade;
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
	v += roughness * rough_water(world_pos.xz);
	v = max(v, 0.0) + lightning_flash * lightning_reflection;
	ALBEDO = vec3(pow(v, DISPLAY_GAMMA));
}
