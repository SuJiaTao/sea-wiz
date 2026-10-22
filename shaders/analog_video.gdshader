shader_type canvas_item;
render_mode unshaded;

// Video stage: the recorded gun-camera signal as it reaches the monitor.
// Runs over the whole screen, symbology included. Every artefact is driven by
// the picture itself: bright detail smears, glows and gets noisier, dark
// areas stay quiet.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;

uniform vec3 phosphor : source_color = vec3(1.0, 1.0, 0.985);
uniform float highlight_bleach : hint_range(0.0, 1.0) = 0.0;

uniform float frame_rate = 29.97;
uniform float frame_lines = 480.0;
uniform float tape_cell_px : hint_range(0.5, 4.0) = 1.0;
uniform float tail_px : hint_range(0.0, 6.0) = 1.3;
uniform float bright_tail_gain : hint_range(0.0, 8.0) = 2.5;
uniform float sharpening : hint_range(0.0, 1.5) = 0.2;
uniform float ghost_offset_px : hint_range(0.0, 20.0) = 7.0;
uniform float ghost_amount : hint_range(0.0, 0.3) = 0.05;
uniform float noise_floor : hint_range(0.0, 0.3) = 0.1;
uniform float noise_signal : hint_range(0.0, 0.6) = 0.3;
uniform float bloom_amount : hint_range(0.0, 2.0) = 0.35;
uniform float bloom_floor : hint_range(0.0, 1.0) = 0.35;
uniform float bloom_lod : hint_range(0.0, 6.0) = 2.5;
uniform float wobble_px : hint_range(0.0, 4.0) = 0.7;
uniform float wobble_lines : hint_range(4.0, 200.0) = 38.0;
uniform float pedestal : hint_range(0.0, 0.2) = 0.02;
uniform float response_gamma : hint_range(0.5, 2.0) = 1.1;
uniform float level_flicker : hint_range(0.0, 0.1) = 0.01;
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.15;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);
const int TAPS = 7;
const float LEAD_SIGMA_TAPS = 0.6;
const float WIDE_SIGMA_TAPS = 3.0;
const float BLEACH_START = 0.55;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float centred_noise(vec2 p) {
	return hash12(p) + hash12(p + 17.31) - 1.0;
}

float smooth_noise(float x, float seed) {
	float i = floor(x);
	float f = smoothstep(0.0, 1.0, fract(x));
	return mix(centred_noise(vec2(i, seed)), centred_noise(vec2(i + 1.0, seed)), f);
}

float luma_at(vec2 uv) {
	return dot(texture(screen_texture, uv).rgb, LUMA);
}

float tape_noise(float x_px, float line, float frame) {
	return centred_noise(vec2(floor(x_px / tape_cell_px), line) + vec2(frame * 61.7, frame * 23.3));
}

float timebase_wobble_px(float line, float frame) {
	return smooth_noise(line / wobble_lines + frame * 0.37, frame * 0.013) * wobble_px;
}

float recorded_luma(vec2 uv, float pixel_width, float line, float frame) {
	float trail = 0.0;
	float trail_weight = 0.0;
	float wide = 0.0;
	float wide_weight = 0.0;
	for (int i = -TAPS; i <= TAPS; i++) {
		float k = float(i);
		vec2 tap_uv = uv + vec2(k * pixel_width, 0.0);
		float value = luma_at(tap_uv);
		value += tape_noise(tap_uv.x / pixel_width, line, frame) * (noise_floor + noise_signal * value);
		float reach = tail_px * (1.0 + bright_tail_gain * value);
		float w_trail = k <= 0.0 ? exp(k / max(reach, 0.001)) : exp(-0.5 * pow(k / LEAD_SIGMA_TAPS, 2.0));
		float w_wide = exp(-0.5 * pow(k / WIDE_SIGMA_TAPS, 2.0));
		trail += value * w_trail;
		trail_weight += w_trail;
		wide += value * w_wide;
		wide_weight += w_wide;
	}
	trail /= trail_weight;
	wide /= wide_weight;
	return trail + (trail - wide) * sharpening;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float pixel_width = SCREEN_PIXEL_SIZE.x;
	float frame = floor(TIME * frame_rate);
	float line = floor(uv.y * frame_lines);

	uv.x += timebase_wobble_px(line, frame) * pixel_width;
	float l = recorded_luma(uv, pixel_width, line, frame);

	float glow = dot(textureLod(screen_texture, uv, bloom_lod).rgb, LUMA);
	l += max(glow - bloom_floor, 0.0) * bloom_amount;
	l += luma_at(uv - vec2(ghost_offset_px * pixel_width, 0.0)) * ghost_amount;

	l = pedestal + (1.0 - pedestal) * pow(clamp(l, 0.0, 1.0), response_gamma);
	l *= 1.0 + centred_noise(vec2(frame, 0.5)) * level_flicker;

	vec2 from_centre = SCREEN_UV - vec2(0.5);
	l *= 1.0 - vignette_amount * dot(from_centre, from_centre) * 2.0;
	l = clamp(l, 0.0, 1.0);

	vec3 colour = phosphor * l;
	colour = mix(colour, vec3(l), smoothstep(BLEACH_START, 1.0, l) * highlight_bleach);
	COLOR = vec4(colour, 1.0);
}
