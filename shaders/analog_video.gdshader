shader_type canvas_item;
render_mode unshaded;

// Video stage: the gun-camera picture recorded to tape and played back, the
// same signal path as Roll's VHS look in monochrome. Runs over the whole
// screen, symbology included. Lengths are in pixels at 480 lines.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;

uniform vec3 phosphor : source_color = vec3(1.0, 1.0, 0.985);
uniform float highlight_bleach : hint_range(0.0, 1.0) = 0.0;

uniform float frame_rate = 29.97;
uniform float luma_band : hint_range(0.1, 1.0) = 0.42;
uniform float smear_level : hint_range(0.0, 1.0) = 0.7;
uniform float smear_gain : hint_range(0.0, 1.0) = 0.25;
uniform float smear_band : hint_range(0.01, 0.5) = 0.0417;
uniform float smear_delay : hint_range(0.0, 10.0) = 3.0;
uniform float halo : hint_range(0.0, 2.0) = 0.8;
uniform float halo_coring : hint_range(0.0, 0.1) = 0.015;
uniform float halo_lod : hint_range(0.0, 5.0) = 2.8;
uniform float luma_noise : hint_range(0.0, 0.3) = 0.06;
uniform float dark_noise : hint_range(0.0, 4.0) = 1.6;
uniform float grain_length : hint_range(1.0, 12.0) = 3.0;
uniform float wave_amplitude : hint_range(0.0, 3.0) = 0.6;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);
const float LINES = 480.0;
const float LANCZOS_LOBES = 3.0;
const int LUMA_TAPS = 7;
const int SMEAR_TAPS = 12;
const float SMEAR_PREFILTER_LOD = 1.5;
const float MIN_DARK_NOISE = 0.35;
const float BLEACH_START = 0.55;
const float WAVE_REACH_LINES = 45.0;
const float WAVE_RANDOM = 0.1;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float gaussian_noise(vec2 p) {
	return (hash12(p) + hash12(p + 19.19) + hash12(p + 41.7) - 1.5) / 1.5;
}

float lanczos3(float x) {
	float ax = abs(x);
	if (ax >= LANCZOS_LOBES) {
		return 0.0;
	}
	if (ax < 0.0001) {
		return 1.0;
	}
	float p = PI * x;
	return LANCZOS_LOBES * sin(p) * sin(p / LANCZOS_LOBES) / (p * p);
}

float luma_at(vec2 uv) {
	return dot(texture(screen_texture, uv).rgb, LUMA);
}

float edge_wave_px(float line, float frame, float u) {
	float t = TIME;
	float patch_a = LINES * (0.5 + 0.42 * sin(0.11 * t));
	float patch_b = LINES * (0.5 + 0.42 * sin(0.07 * t + 2.1));
	float near = max(
		exp(-pow((line - patch_a) / WAVE_REACH_LINES, 2.0)),
		exp(-pow((line - patch_b) / WAVE_REACH_LINES, 2.0))
	);
	float envelope = 0.15 + 0.85 * near;
	float w = 0.6 * sin(TAU * line / 70.0 + t * 2.0)
		+ 0.3 * sin(TAU * line / 23.0 - t * 3.1 + 1.3)
		+ WAVE_RANDOM * (2.0 * hash12(vec2(line, frame)) - 1.0);
	return wave_amplitude * u * 1.5 * envelope * w;
}

float band_limited_luma(vec2 uv, float px, float u) {
	float total = 0.0;
	float weight = 0.0;
	for (int i = -LUMA_TAPS; i <= LUMA_TAPS; i++) {
		float k = float(i);
		float w = lanczos3(k * luma_band);
		total += w * luma_at(uv + vec2(k * u * px, 0.0));
		weight += w;
	}
	return total / weight;
}

float highlight_smear(vec2 uv, float px, float u) {
	float stride = LANCZOS_LOBES / smear_band / float(SMEAR_TAPS) * u;
	vec2 source = uv - vec2(smear_delay * u * px, 0.0);
	float total = 0.0;
	float weight = 0.0;
	for (int i = -SMEAR_TAPS; i <= SMEAR_TAPS; i++) {
		float k = float(i) * stride;
		float w = lanczos3(k / u * smear_band);
		float level = dot(textureLod(screen_texture, source + vec2(k * px, 0.0), SMEAR_PREFILTER_LOD).rgb, LUMA);
		total += w * clamp((level - smear_level) / (1.0 - smear_level), 0.0, 1.0);
		weight += w;
	}
	return max(total / weight, 0.0);
}

float tape_grain(float x_px, float row, float frame, float u) {
	float along = x_px / (grain_length * u);
	float cell = floor(along);
	vec2 offset = vec2(hash12(vec2(frame, 3.1)), hash12(vec2(frame, 7.9))) * 512.0;
	float a = gaussian_noise(vec2(cell, row) + offset);
	float b = gaussian_noise(vec2(cell + 1.0, row) + offset);
	return mix(a, b, fract(along));
}

float screen_blend(float a, float b) {
	return a + b - a * b;
}

void fragment() {
	float px = SCREEN_PIXEL_SIZE.x;
	float u = (1.0 / SCREEN_PIXEL_SIZE.y) / LINES;
	float frame = floor(TIME * frame_rate);
	float line = floor(SCREEN_UV.y * LINES);

	vec2 uv = SCREEN_UV;
	uv.x -= edge_wave_px(line, frame, u) * px;

	float y = band_limited_luma(uv, px, u);
	y = screen_blend(y, highlight_smear(uv, px, u) * smear_gain);

	float soft = dot(textureLod(screen_texture, uv, halo_lod + log2(u)).rgb, LUMA);
	float edge = y - soft;
	y = clamp(y + halo * sign(edge) * max(0.0, abs(edge) - halo_coring), 0.0, 1.0);

	float dark = max(MIN_DARK_NOISE, clamp(1.0 - dark_noise * y, 0.0, 1.0));
	y += dark * luma_noise * tape_grain(uv.x / px, line, frame, u);
	y = clamp(y, 0.0, 1.0);

	vec3 colour = phosphor * y;
	colour = mix(colour, vec3(y), smoothstep(BLEACH_START, 1.0, y) * highlight_bleach);
	COLOR = vec4(colour, 1.0);
}
