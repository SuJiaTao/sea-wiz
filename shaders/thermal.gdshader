shader_type canvas_item;
render_mode unshaded;

// Sensor stage: what the FLIR head itself produces, before the video chain.
// Optical softness, bloom on hot bodies and detail-peaking halos.

uniform float gain : hint_range(0.2, 4.0) = 1.35;
uniform float black_level : hint_range(0.0, 0.5) = 0.02;
uniform float levels : hint_range(2.0, 256.0) = 64.0;
uniform float sensor_floor : hint_range(0.0, 0.3) = 0.035;
uniform float optical_blur : hint_range(0.0, 1.0) = 0.55;
uniform float optical_blur_texels : hint_range(0.25, 2.0) = 0.7;
uniform float polarity : hint_range(0.0, 1.0) = 0.0;
uniform float bloom_amount : hint_range(0.0, 2.0) = 0.9;
uniform float bloom_floor : hint_range(0.0, 1.0) = 0.42;
uniform float bloom_radius_texels : hint_range(0.5, 4.0) = 1.4;
uniform float halo_amount : hint_range(0.0, 2.0) = 0.75;
uniform float halo_radius_texels : hint_range(1.0, 8.0) = 2.8;
uniform float shake_x = 0.0;
uniform float shake_y = 0.0;
uniform vec2 sensor_size = vec2(320.0, 180.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;

const vec3 LUMA = vec3(0.30, 0.59, 0.11);
const int RING_TAPS = 8;

vec2 ring_direction(int tap) {
	float angle = TAU * float(tap) / float(RING_TAPS);
	return vec2(cos(angle), sin(angle));
}

void fragment() {
	vec2 uv = clamp(UV + vec2(shake_x, shake_y), vec2(0.0), vec2(1.0));
	vec2 texel = 1.0 / sensor_size;

	float centre = dot(texture(TEXTURE, uv).rgb, LUMA);
	float soft = 0.0;
	float near = 0.0;
	float far = 0.0;
	for (int i = 0; i < RING_TAPS; i++) {
		vec2 direction = ring_direction(i) * texel;
		soft += dot(texture(TEXTURE, uv + direction * optical_blur_texels).rgb, LUMA);
		near += dot(texture(TEXTURE, uv + direction * bloom_radius_texels).rgb, LUMA);
		far += dot(texture(TEXTURE, uv + direction * halo_radius_texels).rgb, LUMA);
	}
	soft /= float(RING_TAPS);
	near /= float(RING_TAPS);
	far /= float(RING_TAPS);

	float base = mix(centre, soft, optical_blur);
	float l = base + max(near - bloom_floor, 0.0) * bloom_amount;
	l = max(l - black_level, 0.0) * gain;
	l = sensor_floor + l + (base - far) * halo_amount;

	l = clamp(l + flash, 0.0, 1.0);

	l = floor(l * levels + 0.5) / levels;
	l = mix(l, 1.0 - l, polarity);

	COLOR = vec4(vec3(l), 1.0);
}
