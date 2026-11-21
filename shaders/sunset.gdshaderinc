// The sky just after the sun has gone. Straight up it is deep navy, paling
// through blue to a grey haze lower down, then a peach glow, then orange,
// with a thin dark red seam on the sea. The glow is strongest over where the
// sun set. As dusk goes on the bands sink and thin and everything darkens to
// night.

// Colour stops from the horizon up, and the height (the sine of the angle
// above the horizon) at which each one is reached at the start of dusk.
const int STOPS = 7;
const vec3 STOP_COLOURS[7] = vec3[](
	vec3(0.15, 0.03, 0.014),
	vec3(0.3, 0.14, 0.05),
	vec3(0.25, 0.195, 0.13),
	vec3(0.14, 0.165, 0.225),
	vec3(0.078, 0.118, 0.22),
	vec3(0.03, 0.067, 0.165),
	vec3(0.005, 0.023, 0.083)
);
const float STOP_HEIGHTS[7] = float[](0.0, 0.03, 0.09, 0.15, 0.22, 0.32, 0.5);
// Stops below this one are the warm glow, dimmer on the side away from it.
const int WARM_STOPS = 3;
const float FAR_SIDE_WARMTH = 0.6;
const vec3 NIGHT = vec3(0.002, 0.004, 0.012);
// By full night the bands have sunk to this share of their height.
const float BAND_SINK = 0.35;

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
	float up = max(dir.y, 0.0) / mix(1.0, BAND_SINK, dusk);
	float toward = max(dot(normalize(vec3(dir.x, 0.0, dir.z)), glow), 0.0);
	float side = mix(FAR_SIDE_WARMTH, 1.0, toward);
	vec3 sky = STOP_COLOURS[0] * side;
	for (int i = 1; i < STOPS; i++) {
		vec3 colour = STOP_COLOURS[i] * (i < WARM_STOPS ? side : 1.0);
		sky = mix(sky, colour, smoothstep(STOP_HEIGHTS[i - 1], STOP_HEIGHTS[i], up));
	}
	return mix(sky, NIGHT, smoothstep(0.0, 1.0, dusk));
}
