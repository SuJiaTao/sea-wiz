uniform float growth = 1.0;
uniform float growth_curve : hint_range(0.05, 4.0) = 1.0;
uniform float start_heat = 1.0;
uniform float end_heat = 0.0;
uniform float cooling : hint_range(0.05, 8.0) = 1.0;
uniform float start_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float fade : hint_range(0.05, 8.0) = 1.0;
uniform float min_angular_size : hint_range(0.0, 0.02) = 0.0;

const float DISPLAY_GAMMA = 2.2;
const float CULLED_SIZE = 0.0001;

float particle_size(float base, float progress, float depth) {
	float size = base * (1.0 + (growth - 1.0) * pow(progress, growth_curve));
	return max(size, depth * min_angular_size) * step(CULLED_SIZE, base);
}

float particle_heat(float progress) {
	return mix(end_heat, start_heat, pow(1.0 - progress, cooling));
}

float particle_alpha(float progress) {
	return start_alpha * pow(1.0 - progress, fade);
}

vec3 display_to_linear(float level) {
	return vec3(pow(max(level, 0.0), DISPLAY_GAMMA));
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(0.0, 1.0, fract(p));
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float billow_noise(vec2 p) {
	return value_noise(p) * 0.55 + value_noise(p * 2.1 + 7.3) * 0.3 + value_noise(p * 4.3 + 3.1) * 0.15;
}
