// The sky just after the sun has gone: a red seam on the sea, a band of
// gold and pale cream, a clear pale blue, then violet and a dusky purple
// overhead. The glow is strongest over where the sun set. A few thin cloud
// streaks hang low, lit from below near the horizon. As dusk goes on the
// bands sink and thin and everything darkens to night.

// Colour stops from the horizon up, and the height (the sine of the angle
// above the horizon) at which each one is reached at the start of dusk.
const int STOPS = 9;
const vec3 STOP_COLOURS[9] = vec3[](
	vec3(0.33, 0.032, 0.012),
	vec3(0.275, 0.048, 0.015),
	vec3(0.47, 0.385, 0.113),
	vec3(0.465, 0.487, 0.25),
	vec3(0.43, 0.58, 0.59),
	vec3(0.28, 0.476, 0.633),
	vec3(0.157, 0.225, 0.376),
	vec3(0.063, 0.051, 0.085),
	vec3(0.022, 0.011, 0.013)
);
const float STOP_HEIGHTS[9] = float[](0.0, 0.015, 0.05, 0.08, 0.13, 0.2, 0.3, 0.42, 0.6);
// Stops below this one are the warm glow, dimmer on the side away from it.
const int WARM_STOPS = 4;
const float FAR_SIDE_WARMTH = 0.7;
const vec3 NIGHT = vec3(0.002, 0.003, 0.01);
// By full night the bands have sunk to this share of their height.
const float BAND_SINK = 0.35;
const vec3 CLOUD_DARK = vec3(0.05, 0.045, 0.06);
const vec3 CLOUD_LIT = vec3(0.6, 0.16, 0.04);
const float CLOUD_COVER = 0.64;
const float CLOUD_OPACITY = 0.8;
const float CLOUD_TOP = 0.25;

float sunset_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float sunset_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(sunset_hash(i), sunset_hash(i + vec2(1.0, 0.0)), u.x),
		mix(sunset_hash(i + vec2(0.0, 1.0)), sunset_hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float sunset_fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 5; octave++) {
		total += sunset_noise(p) * amplitude;
		p *= 2.02;
		amplitude *= 0.5;
	}
	return total;
}

vec3 sunset_glow_direction(float bearing_deg) {
	float b = radians(bearing_deg);
	return vec3(sin(b), 0.0, -cos(b));
}

// dusk runs from 0, just after sunset, to 1, full night.
vec3 sunset_sky(vec3 dir, vec3 glow, float dusk) {
	float height = max(dir.y, 0.0);
	float up = height / mix(1.0, BAND_SINK, dusk);
	float toward = max(dot(normalize(vec3(dir.x, 0.0, dir.z)), glow), 0.0);
	float side = mix(FAR_SIDE_WARMTH, 1.0, toward);
	vec3 sky = STOP_COLOURS[0] * side;
	for (int i = 1; i < STOPS; i++) {
		vec3 colour = STOP_COLOURS[i] * (i < WARM_STOPS ? side : 1.0);
		sky = mix(sky, colour, smoothstep(STOP_HEIGHTS[i - 1], STOP_HEIGHTS[i], up));
	}
	// Long thin streaks, foreshortened toward the horizon. Low down on the
	// glow's side their undersides still catch the light.
	vec2 drift = dir.xz / max(dir.y + 0.08, 0.02);
	float streak = sunset_fbm(drift * vec2(0.35, 1.6));
	float band = smoothstep(0.01, 0.05, height) * smoothstep(CLOUD_TOP, CLOUD_TOP * 0.4, height);
	float cloud = smoothstep(CLOUD_COVER, CLOUD_COVER + 0.15, streak) * band;
	float underlit = pow(toward, 1.5) * smoothstep(0.2, 0.02, height) * (1.0 - dusk);
	sky = mix(sky, mix(CLOUD_DARK, CLOUD_LIT, underlit), cloud * CLOUD_OPACITY);
	return mix(sky, NIGHT, smoothstep(0.0, 1.0, dusk));
}
