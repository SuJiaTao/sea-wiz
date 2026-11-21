// A sunset over open sea, driven only by how high the sun is. The disc
// stays a hot pale gold in a blazing orange sky right down to the water.
// Once it is under, a fierce red-orange band holds along the horizon and
// thins, the sky above turns steel blue and then deep blue, and streaks of
// cloud go slate grey with their undersides still burning near the horizon.

const vec3 HORIZON_HOT = vec3(0.8, 0.24, 0.02);
const vec3 HORIZON_SEAM = vec3(0.75, 0.08, 0.005);
const vec3 HORIZON_FAR = vec3(0.62, 0.14, 0.015);
const vec3 SKY_MID = vec3(0.46, 0.1, 0.015);
const vec3 SKY_HIGH = vec3(0.24, 0.045, 0.012);
const vec3 SUN_CORE = vec3(3.0, 2.0, 0.85);
const vec3 SUN_GLOW = vec3(0.9, 0.38, 0.05);
const vec3 SUN_HALO = vec3(0.7, 0.18, 0.01);
const vec3 CLOUD_DARK = vec3(0.2, 0.05, 0.03);
const vec3 CLOUD_RIM = vec3(1.0, 0.45, 0.08);
const vec3 TWILIGHT_GLOW = vec3(0.85, 0.09, 0.005);
const vec3 TWILIGHT_GAP = vec3(0.42, 0.2, 0.05);
const vec3 TWILIGHT_MID = vec3(0.07, 0.12, 0.2);
const vec3 TWILIGHT_HIGH = vec3(0.02, 0.04, 0.09);
const vec3 TWILIGHT_CLOUD = vec3(0.04, 0.045, 0.065);
const vec3 CLOUD_AFTERGLOW = vec3(1.0, 0.22, 0.03);
const vec3 EARTH_SHADOW = vec3(0.05, 0.07, 0.12);
const vec3 NIGHT = vec3(0.004, 0.007, 0.016);
const float SUN_RADIUS = 0.02;
const float SUN_EDGE = 0.003;
const float SEAM_HEIGHT = 0.05;
const float SEAM_FULL_ELEVATION = 1.6;
// Degrees under the horizon by which twilight has run out.
const float TWILIGHT_DEPTH = 9.0;

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

float sunset_elevation(vec3 sun) {
	return degrees(asin(clamp(sun.y, -1.0, 1.0)));
}

// 0 at the moment of sunset, 1 when twilight has run out.
float sunset_dusk(vec3 sun) {
	return smoothstep(0.0, TWILIGHT_DEPTH, -sunset_elevation(sun));
}

vec3 sunset_twilight(vec3 dir, float up, float near_side, float dusk) {
	float band = mix(0.05, 0.015, dusk);
	float fading = 1.0 - smoothstep(0.45, 1.0, dusk);
	vec3 sky = mix(TWILIGHT_MID, TWILIGHT_HIGH, smoothstep(0.0, 0.6, up)) * (1.0 - 0.7 * dusk);
	sky = mix(sky, EARTH_SHADOW * (1.0 - 0.7 * dusk), (1.0 - near_side) * smoothstep(0.25, 0.0, up) * 0.6);
	float reach = mix(0.45, 1.0, pow(near_side, 2.0)) * fading;
	sky = mix(sky, TWILIGHT_GAP, exp(-up / (band * 3.0)) * reach * 0.7);
	sky = mix(sky, TWILIGHT_GLOW, exp(-up / band) * reach);
	return sky;
}

vec3 sunset_sky(vec3 dir, vec3 sun, float daylight, float time, bool with_disc) {
	float dusk = sunset_dusk(sun);
	float up = max(dir.y, 0.0);
	float near_side = max(dot(normalize(vec3(dir.x, 0.0, dir.z)), normalize(vec3(sun.x, 0.0, sun.z))), 0.0);
	vec3 horizon = mix(HORIZON_FAR, HORIZON_HOT, pow(near_side, 3.0));
	vec3 sky = mix(horizon, SKY_MID, smoothstep(0.0, 0.2, up));
	sky = mix(sky, SKY_HIGH, smoothstep(0.15, 0.7, up));
	float facing = max(dot(dir, sun), 0.0);
	sky += SUN_HALO * pow(facing, 5.0) * 0.5;
	sky += SUN_GLOW * (pow(facing, 30.0) * 0.45 + pow(facing, 300.0) * 0.7);
	// Right down at sea level the light has crossed the most air and runs red,
	// more so the lower the sun gets.
	float setting = 1.0 - smoothstep(0.0, SEAM_FULL_ELEVATION, sunset_elevation(sun));
	sky = mix(sky, HORIZON_SEAM, smoothstep(SEAM_HEIGHT, 0.0, up) * mix(0.5, 0.95, setting));
	// The sky overhead goes blue first while the horizon is still burning.
	sky = mix(sky, sunset_twilight(dir, up, near_side, dusk), smoothstep(0.0, 0.25, dusk * (1.0 + up * 3.0)));
	vec2 drift = dir.xz / max(dir.y + 0.08, 0.02);
	float streak = sunset_fbm(drift * vec2(0.35, 1.6) + vec2(time * 0.004, 0.0));
	float spread = smoothstep(0.01, 0.06, up) * smoothstep(0.35, 0.12, up);
	float cloud = smoothstep(0.52, 0.72, streak) * spread;
	vec3 lit_cloud = mix(CLOUD_DARK, CLOUD_RIM, pow(facing, 6.0) * 0.9 + near_side * 0.15);
	// After sunset the clouds go slate, their undersides burning only low down on the sun's side.
	float underlit = pow(near_side, 1.5) * smoothstep(0.22, 0.02, up) * (1.0 - smoothstep(0.3, 0.85, dusk));
	vec3 dusk_cloud = mix(TWILIGHT_CLOUD * (1.0 - 0.7 * dusk), CLOUD_AFTERGLOW, underlit);
	sky = mix(sky, mix(lit_cloud, dusk_cloud, smoothstep(0.0, 0.3, dusk)), cloud * 0.85);
	if (with_disc) {
		float disc = smoothstep(SUN_RADIUS + SUN_EDGE, SUN_RADIUS, acos(clamp(facing, -1.0, 1.0)));
		sky = mix(sky, SUN_CORE, disc * (1.0 - cloud * 0.7));
	}
	return mix(NIGHT, sky, daylight);
}

vec3 sunset_sun_direction(float elevation_deg, float bearing_deg) {
	float e = radians(elevation_deg);
	float b = radians(bearing_deg);
	return vec3(sin(b) * cos(e), sin(e), -cos(b) * cos(e));
}
