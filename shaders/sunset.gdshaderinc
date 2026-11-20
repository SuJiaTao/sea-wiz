// A low sun over the sea: a red-orange band along the horizon cooling to
// crimson and deep blue overhead, a glow around the sun and thin cloud streaks lit
// from below. As the sun drops the warmth drains and night comes in.

const vec3 HORIZON_HOT = vec3(1.0, 0.3, 0.05);
const vec3 HORIZON_FAR = vec3(0.75, 0.12, 0.06);
const vec3 SKY_MID = vec3(0.42, 0.05, 0.04);
const vec3 SKY_HIGH = vec3(0.025, 0.03, 0.09);
const vec3 AFTERGLOW = vec3(0.5, 0.08, 0.04);
const vec3 NIGHT = vec3(0.006, 0.008, 0.02);
const vec3 SUN_CORE = vec3(4.0, 2.6, 1.3);
const vec3 SUN_GLOW = vec3(1.0, 0.38, 0.12);
const vec3 CLOUD_DARK = vec3(0.14, 0.04, 0.07);
const vec3 CLOUD_RIM = vec3(1.0, 0.32, 0.1);
const float SUN_RADIUS = 0.016;
const float SUN_EDGE = 0.003;

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

vec3 sunset_sky(vec3 dir, vec3 sun, float daylight, float time, bool with_disc) {
	float up = max(dir.y, 0.0);
	float toward = max(dot(normalize(vec3(dir.x, 0.0, dir.z)), normalize(vec3(sun.x, 0.0, sun.z))), 0.0);
	vec3 horizon = mix(HORIZON_FAR, HORIZON_HOT, pow(toward, 3.0));
	vec3 sky = mix(horizon, SKY_MID, smoothstep(0.0, 0.16, up));
	sky = mix(sky, SKY_HIGH, smoothstep(0.1, 0.55, up));
	float facing = max(dot(dir, sun), 0.0);
	sky += SUN_GLOW * (pow(facing, 12.0) * 0.6 + pow(facing, 120.0) * 1.2);
	vec2 drift = dir.xz / max(dir.y + 0.08, 0.02);
	float streak = sunset_fbm(drift * vec2(0.35, 1.6) + vec2(time * 0.004, 0.0));
	float band = smoothstep(0.01, 0.06, up) * smoothstep(0.35, 0.12, up);
	float cloud = smoothstep(0.52, 0.72, streak) * band;
	vec3 cloud_colour = mix(CLOUD_DARK, CLOUD_RIM, pow(facing, 6.0) * 0.9 + toward * 0.15);
	sky = mix(sky, cloud_colour, cloud * 0.85);
	float disc = smoothstep(SUN_RADIUS + SUN_EDGE, SUN_RADIUS, acos(clamp(facing, -1.0, 1.0)));
	if (with_disc) {
		sky = mix(sky, SUN_CORE, disc * (1.0 - cloud * 0.7));
	}
	vec3 night = mix(NIGHT, SKY_HIGH * 0.25, smoothstep(0.3, 0.0, up) * 0.4);
	float afterglow = smoothstep(0.12, 0.0, up) * pow(toward, 2.0) * smoothstep(0.0, 0.5, daylight);
	return mix(night, sky, daylight * daylight) + AFTERGLOW * afterglow * (1.0 - daylight);
}

vec3 sunset_sun_direction(float elevation_deg, float bearing_deg) {
	float e = radians(elevation_deg);
	float b = radians(bearing_deg);
	return vec3(sin(b) * cos(e), sin(e), -cos(b) * cos(e));
}
