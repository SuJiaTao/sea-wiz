shader_type canvas_item;
render_mode unshaded;

// Video stage: the gun-camera picture recorded to tape and shown on a CRT.
// Runs over the whole screen, symbology included.
// Tape: each scan line holds a limited number of samples, so fine detail
// smudges slightly; bright detail leaves a dark streak to its right; grain
// sits on the samples, mostly in the dark parts.
// CRT: every line is drawn by a beam that fattens with brightness, so dark
// areas show the line structure and bright areas fill in.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;

uniform vec3 phosphor : source_color = vec3(1.0, 1.0, 0.985);
uniform float highlight_bleach : hint_range(0.0, 1.0) = 0.0;

uniform float frame_rate = 29.97;
uniform float video_lines : hint_range(120.0, 960.0) = 480.0;
uniform float line_samples : hint_range(120.0, 1920.0) = 900.0;
uniform float sample_hold : hint_range(0.0, 0.5) = 0.15;
uniform float tail_samples : hint_range(0.0, 4.0) = 0.4;
uniform float streak_length : hint_range(0.0, 120.0) = 36.0;
uniform float streak_amount : hint_range(0.0, 1.0) = 0.35;
uniform float streak_floor : hint_range(0.0, 0.95) = 0.5;
uniform float black_lift : hint_range(0.0, 0.3) = 0.0;
uniform float head_switch_lines : hint_range(0.0, 20.0) = 5.0;
uniform float head_switch_samples : hint_range(0.0, 30.0) = 6.0;
uniform float capture_border : hint_range(0.0, 0.05) = 0.006;
uniform float sharpening : hint_range(0.0, 1.5) = 0.45;
uniform float sharpening_coring : hint_range(0.0, 0.1) = 0.02;
uniform float grain_amount : hint_range(0.0, 0.4) = 0.06;
uniform float dark_grain : hint_range(0.0, 4.0) = 1.6;
uniform float beam_sigma_dark : hint_range(0.1, 0.6) = 0.36;
uniform float beam_sigma_bright : hint_range(0.1, 0.8) = 0.5;
uniform float bloom_amount : hint_range(0.0, 2.0) = 0.3;
uniform float bloom_floor : hint_range(0.0, 1.0) = 0.4;
uniform float bloom_lines : hint_range(1.0, 64.0) = 8.0;
uniform float wobble_samples : hint_range(0.0, 2.0) = 0.25;
uniform float wobble_lines : hint_range(4.0, 200.0) = 30.0;
uniform float level_flicker : hint_range(0.0, 0.1) = 0.01;
uniform float chroma_amount : hint_range(0.0, 3.0) = 0.9;
uniform float chroma_lines : hint_range(1.0, 64.0) = 3.0;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);
const int TAIL_TAPS = 4;
const int STREAK_TAPS = 8;
const float STREAK_FALLOFF = 2.0;
const float HEAD_SWITCH_JITTER = 0.35;
const float BORDER_JAGGIES = 0.0015;
const int LEAD_TAPS = 3;
const float LEAD_SIGMA = 0.6;
const float WIDE_SIGMA = 2.0;
const float MIN_DARK_GRAIN = 0.35;
const float BLEACH_START = 0.55;
const float SQRT_TAU = 2.50662827;
const float GRAIN_TILE = 512.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float centred_noise(vec2 p) {
	return hash12(p) + hash12(p + 19.19) - 1.0;
}

float smooth_noise(float x, float seed) {
	float i = floor(x);
	float f = smoothstep(0.0, 1.0, fract(x));
	return mix(centred_noise(vec2(i, seed)), centred_noise(vec2(i + 1.0, seed)), f);
}

float timebase_wobble(float line, float frame) {
	return smooth_noise(line / wobble_lines + frame * 0.37, frame * 0.013) * wobble_samples;
}

float tape_sample(float index, float line, vec2 grain_offset) {
	vec2 uv = vec2((index + 0.5) / line_samples, (line + 0.5) / video_lines);
	float value = dot(textureLod(screen_texture, uv, 0.0).rgb, LUMA);
	float dark = max(MIN_DARK_GRAIN, clamp(1.0 - dark_grain * value, 0.0, 1.0));
	return value + dark * grain_amount * centred_noise(vec2(index, line) + grain_offset);
}

float trail_weight(float k) {
	if (k > 0.0) {
		return exp(-0.5 * pow(k / LEAD_SIGMA, 2.0));
	}
	return exp(k / max(tail_samples, 0.001));
}

float streak(float xs, float line) {
	float total = 0.0;
	float weight = 0.0;
	for (int k = 1; k <= STREAK_TAPS; k++) {
		float along = float(k) / float(STREAK_TAPS);
		vec2 uv = vec2((xs - along * streak_length) / line_samples, (line + 0.5) / video_lines);
		float value = dot(textureLod(screen_texture, uv, 0.0).rgb, LUMA);
		float w = exp(-along * STREAK_FALLOFF);
		total += w * max(value - streak_floor, 0.0) / (1.0 - streak_floor);
		weight += w;
	}
	return total / weight;
}

float head_switch(float line, float frame) {
	float into = (line - (video_lines - head_switch_lines)) / max(head_switch_lines, 1.0);
	if (into <= 0.0) {
		return 0.0;
	}
	float jitter = 1.0 + centred_noise(vec2(line, frame)) * HEAD_SWITCH_JITTER;
	return head_switch_samples * into * into * jitter;
}

float cored_sharpen(float trail, float wide) {
	float edge = trail - wide;
	return trail + sign(edge) * max(abs(edge) - sharpening_coring, 0.0) * sharpening;
}

float line_signal(float xs, float line, vec2 grain_offset) {
	float i = floor(xs - 0.5);
	float t0 = 0.0;
	float w0 = 0.0;
	float t1 = 0.0;
	float w1 = 0.0;
	float wide0 = 0.0;
	float wide1 = 0.0;
	float ww0 = 0.0;
	float ww1 = 0.0;
	for (int n = -TAIL_TAPS; n <= LEAD_TAPS + 1; n++) {
		float value = tape_sample(i + float(n), line, grain_offset);
		float k0 = float(n);
		float k1 = float(n) - 1.0;
		if (n <= LEAD_TAPS) {
			float a = trail_weight(k0);
			t0 += value * a;
			w0 += a;
			float b = exp(-0.5 * pow(k0 / WIDE_SIGMA, 2.0));
			wide0 += value * b;
			ww0 += b;
		}
		if (n >= -TAIL_TAPS + 1) {
			float a = trail_weight(k1);
			t1 += value * a;
			w1 += a;
			float b = exp(-0.5 * pow(k1 / WIDE_SIGMA, 2.0));
			wide1 += value * b;
			ww1 += b;
		}
	}
	float s0 = cored_sharpen(t0 / w0, wide0 / ww0);
	float s1 = cored_sharpen(t1 / w1, wide1 / ww1);
	float blend = smoothstep(0.5 - sample_hold, 0.5 + sample_hold, fract(xs - 0.5));
	float held = mix(s0, s1, blend);
	return held - streak(xs, line) * streak_amount * (1.0 - clamp(held, 0.0, 1.0));
}

float beam(float distance_lines, float value) {
	float sigma = mix(beam_sigma_dark, beam_sigma_bright, sqrt(clamp(value, 0.0, 1.0)));
	return value * exp(-0.5 * pow(distance_lines / sigma, 2.0)) / (sigma * SQRT_TAU);
}

void fragment() {
	float frame = floor(TIME * frame_rate);
	float y_lines = SCREEN_UV.y * video_lines;
	float line = floor(y_lines);
	float from_centre = fract(y_lines) - 0.5;
	float neighbour = line + sign(from_centre);

	float xs = SCREEN_UV.x * line_samples;
	vec2 grain_offset = vec2(hash12(vec2(frame, 3.1)), hash12(vec2(frame, 7.9))) * GRAIN_TILE;
	float near_shift = timebase_wobble(line, frame) - head_switch(line, frame);
	float far_shift = timebase_wobble(neighbour, frame) - head_switch(neighbour, frame);
	float near_signal = line_signal(xs + near_shift, line, grain_offset);
	float far_signal = line_signal(xs + far_shift, neighbour, grain_offset);
	float l = beam(from_centre, near_signal) + beam(1.0 - abs(from_centre), far_signal);

	float glow_lod = log2(max((1.0 / SCREEN_PIXEL_SIZE.y) / video_lines * bloom_lines, 1.0));
	float glow = dot(textureLod(screen_texture, SCREEN_UV, glow_lod).rgb, LUMA);
	l += max(glow - bloom_floor, 0.0) * bloom_amount;
	l *= 1.0 + centred_noise(vec2(frame, 0.5)) * level_flicker;
	l = black_lift + (1.0 - black_lift) * clamp(l, 0.0, 1.0);
	l *= step(capture_border + centred_noise(vec2(line, frame * 0.1)) * BORDER_JAGGIES, SCREEN_UV.x);

	vec3 colour = phosphor * l;
	colour = mix(colour, vec3(l), smoothstep(BLEACH_START, 1.0, l) * highlight_bleach);
	float chroma_lod = log2(max((1.0 / SCREEN_PIXEL_SIZE.y) / video_lines * chroma_lines, 1.0));
	vec3 smeared = textureLod(screen_texture, SCREEN_UV, chroma_lod).rgb;
	colour = clamp(colour + (smeared - vec3(dot(smeared, LUMA))) * chroma_amount, 0.0, 1.0);
	COLOR = vec4(colour, 1.0);
}
