// A sunset over open sea, driven only by how high the sun is. Low down, its
// light crosses so much air that the disc dims, reddens and squashes flat.
// Once it is under, the sky does not go dark at once: a glow holds on the
// horizon where it set and narrows to a red seam, the sky overhead cools to
// deep blue, clouds stay lit from below for a while and then turn black, and
// the earth's shadow climbs up the opposite sky.

const vec3 HORIZON_HOT = vec3(0.85, 0.27, 0.05);
const vec3 HORIZON_FAR = vec3(0.68, 0.14, 0.04);
const vec3 SKY_MID = vec3(0.4, 0.05, 0.04);
const vec3 SKY_HIGH = vec3(0.07, 0.012, 0.03);
const vec3 SUN_CORE = vec3(2.2, 0.8, 0.22);
const vec3 SUN_LOW = vec3(1.0, 0.16, 0.03);
const vec3 SUN_GLOW = vec3(0.7, 0.26, 0.06);
const vec3 SUN_HALO = vec3(0.8, 0.2, 0.04);
const vec3 CLOUD_DARK = vec3(0.16, 0.03, 0.03);
const vec3 CLOUD_RIM = vec3(1.0, 0.45, 0.08);
const vec3 CLOUD_AFTERGLOW = vec3(0.75, 0.12, 0.08);
const vec3 TWILIGHT_GLOW = vec3(0.6, 0.1, 0.02);
const vec3 TWILIGHT_HIGH = vec3(0.02, 0.018, 0.045);
const vec3 EARTH_SHADOW = vec3(0.04, 0.035, 0.07);
const vec3 SHADOW_BELT = vec3(0.22, 0.06, 0.08);
const vec3 NIGHT = vec3(0.006, 0.005, 0.012);
const float SUN_RADIUS = 0.02;
const float SUN_EDGE = 0.003;
// Degrees of sun height over which each stage plays out.
const float LOW_SUN = 4.0;
const float TWILIGHT_DEPTH = 9.0;
// Refraction squashes the disc to about four fifths of its width at the horizon.
const float FLATTENING = 1.25;

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

// 1 with the sun on the horizon, 0 once it is a few degrees up.
float sunset_lowness(vec3 sun) {
	return 1.0 - smoothstep(0.0, LOW_SUN, sunset_elevation(sun));
}

// 0 at the moment of sunset, 1 when twilight has run out.
float sunset_dusk(vec3 sun) {
	return smoothstep(0.0, TWILIGHT_DEPTH, -sunset_elevation(sun));
}

vec3 sunset_sun_colour(vec3 sun) {
	return mix(SUN_CORE, SUN_LOW, sunset_lowness(sun));
}

vec3 sunset_sky(vec3 dir, vec3 sun, float daylight, float time, bool with_disc) {
	float low = sunset_lowness(sun);
	float dusk = sunset_dusk(sun);
	float up = max(dir.y, 0.0);
	float toward = dot(normalize(vec3(dir.x, 0.0, dir.z)), normalize(vec3(sun.x, 0.0, sun.z)));
	float near_side = max(toward, 0.0);
	float far_side = max(-toward, 0.0);
	vec3 horizon = mix(HORIZON_FAR, HORIZON_HOT, pow(near_side, 3.0));
	vec3 sky = mix(horizon, SKY_MID, smoothstep(0.0, 0.16, up));
	sky = mix(sky, SKY_HIGH, smoothstep(0.1, 0.55, up));
	// After sunset the sky overhead and away from the sun cools first.
	vec3 twilight = mix(TWILIGHT_GLOW * pow(near_side, 2.0), TWILIGHT_HIGH, smoothstep(0.0, mix(0.25, 0.06, dusk), up));
	float shadow_top = mix(0.0, 0.12, dusk);
	vec3 opposite = mix(EARTH_SHADOW, SHADOW_BELT, smoothstep(shadow_top * 0.6, shadow_top, up) * smoothstep(shadow_top + 0.12, shadow_top, up));
	twilight = mix(twilight, opposite, far_side * smoothstep(0.0, 0.3, dusk));
	sky = mix(sky, twilight, smoothstep(0.0, 0.5, dusk));
	float facing = max(dot(dir, sun), 0.0);
	float glare = 1.0 - smoothstep(0.0, 0.25, dusk);
	vec3 sun_colour = sunset_sun_colour(sun);
	sky += SUN_HALO * pow(facing, 5.0) * 0.55 * mix(1.0, 0.7, low) * glare;
	sky += mix(SUN_GLOW, sun_colour * 0.4, low) * (pow(facing, 30.0) * 0.35 + pow(facing, 300.0) * 0.5) * glare;
	vec2 drift = dir.xz / max(dir.y + 0.08, 0.02);
	float streak = sunset_fbm(drift * vec2(0.35, 1.6) + vec2(time * 0.004, 0.0));
	float band = smoothstep(0.01, 0.06, up) * smoothstep(0.35, 0.12, up);
	float cloud = smoothstep(0.52, 0.72, streak) * band;
	// Clouds stay lit from below for a while after the sun is gone, going pink and then black.
	float underlit = 1.0 - smoothstep(0.15, 0.6, dusk);
	vec3 rim = mix(CLOUD_RIM, CLOUD_AFTERGLOW, smoothstep(0.0, 0.3, dusk));
	vec3 cloud_colour = mix(CLOUD_DARK * (1.0 - dusk), rim, (pow(facing, 6.0) * 0.9 + near_side * 0.15) * underlit);
	sky = mix(sky, cloud_colour, cloud * 0.85);
	if (with_disc) {
		float across = acos(clamp(dot(dir, sun), -1.0, 1.0));
		float rise = dir.y - sun.y;
		float squash = mix(1.0, FLATTENING, low);
		float apart = sqrt(max(across * across - rise * rise, 0.0) + rise * rise * squash * squash);
		float disc = smoothstep(SUN_RADIUS + SUN_EDGE, SUN_RADIUS, apart);
		sky = mix(sky, sun_colour, disc * (1.0 - cloud * 0.7));
	}
	return mix(NIGHT, sky, daylight);
}

vec3 sunset_sun_direction(float elevation_deg, float bearing_deg) {
	float e = radians(elevation_deg);
	float b = radians(bearing_deg);
	return vec3(sin(b) * cos(e), sin(e), -cos(b) * cos(e));
}
