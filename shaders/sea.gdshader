shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// Cold sea surface with faint moving clutter. Deliberately very dark so that,
// after the thermal posterise pass, it reads as an almost-black plane with a
// crisp horizon line.

uniform float base_level : hint_range(0.0, 0.5) = 0.026;
uniform float clutter_level : hint_range(0.0, 0.5) = 0.008;
uniform float clutter_scale = 0.006;
uniform float clutter_speed = 0.09;
uniform float falloff = 520.0;

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

varying vec3 world_pos;

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
	ALBEDO = vec3(pow(v, DISPLAY_GAMMA));
}
