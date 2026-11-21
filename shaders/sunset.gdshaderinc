// The sky just after the sun has gone. A fierce red-orange band holds along
// the horizon over where it set, the sky above is steel blue going to deep
// blue, and streaks of slate cloud still burn orange underneath low on the
// glow's side. As dusk runs on the band thins and reddens, the earth's shadow
// rises opposite, the clouds go dark and the sky fades to night.
//
// Heights are measured so that bands of sky run straight across the screen
// rather than bowing, and the whole sky can be lowered to meet a sea that
// stops short of the true horizon.

const vec3 TWILIGHT_GLOW = vec3(0.85, 0.09, 0.005);
const vec3 TWILIGHT_RED = vec3(0.85, 0.035, 0.015);
const vec3 TWILIGHT_GAP = vec3(0.42, 0.2, 0.05);
const vec3 TWILIGHT_MID = vec3(0.07, 0.12, 0.2);
const vec3 TWILIGHT_HIGH = vec3(0.02, 0.04, 0.09);
const vec3 EARTH_SHADOW = vec3(0.05, 0.07, 0.12);
const vec3 CLOUD_SLATE = vec3(0.04, 0.045, 0.065);
const vec3 CLOUD_AFTERGLOW = vec3(1.0, 0.22, 0.03);
const vec3 NIGHT = vec3(0.004, 0.007, 0.016);
// The last share of the dusk, when what twilight is left fades to night.
const float NIGHT_SHARE = 0.25;
// Directions this far off the view heading are treated as if this far, so
// the sky behind the camera (seen only in reflections) stays well behaved.
const float MIN_FACING = 0.25;

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

vec3 sunset_twilight(float up, float near_side, float dusk) {
	float band = mix(0.05, 0.015, dusk);
	float fading = 1.0 - smoothstep(0.45, 1.0, dusk);
	vec3 sky = mix(TWILIGHT_MID, TWILIGHT_HIGH, smoothstep(0.0, 0.6, up)) * (1.0 - 0.7 * dusk);
	sky = mix(sky, EARTH_SHADOW * (1.0 - 0.7 * dusk), (1.0 - near_side) * smoothstep(0.25, 0.0, up) * 0.6);
	float reach = mix(0.45, 1.0, pow(near_side, 2.0)) * fading;
	sky = mix(sky, TWILIGHT_GAP, exp(-up / (band * 3.0)) * reach * 0.7);
	sky = mix(sky, mix(TWILIGHT_GLOW, TWILIGHT_RED, smoothstep(0.0, 0.5, dusk)), exp(-up / band) * reach);
	return sky;
}

// dusk runs from 0, the moment of sunset, to 1, full night. heading is the
// camera's view direction across the sea; drop lowers the horizon by that
// much (as a slope below eye level).
vec3 sunset_sky(vec3 dir, vec3 glow, float dusk, vec2 heading, float drop, float time) {
	float facing = max(dot(dir.xz, heading), MIN_FACING);
	float up = max(dir.y / facing + drop, 0.0);
	float near_side = max(dot(normalize(dir.xz), glow.xz), 0.0);
	vec3 sky = sunset_twilight(up, near_side, dusk);
	vec2 drift = dir.xz / max(up * facing + 0.08, 0.02);
	float streak = sunset_fbm(drift * vec2(0.35, 1.6) + vec2(time * 0.004, 0.0));
	float spread = smoothstep(0.01, 0.06, up) * smoothstep(0.35, 0.12, up);
	float cloud = smoothstep(0.52, 0.72, streak) * spread;
	float underlit = pow(near_side, 1.5) * smoothstep(0.22, 0.02, up) * (1.0 - smoothstep(0.3, 0.85, dusk));
	vec3 cloud_colour = mix(CLOUD_SLATE * (1.0 - 0.7 * dusk), CLOUD_AFTERGLOW, underlit);
	sky = mix(sky, cloud_colour, cloud * 0.85);
	return mix(sky, NIGHT, smoothstep(1.0 - NIGHT_SHARE, 1.0, dusk));
}
