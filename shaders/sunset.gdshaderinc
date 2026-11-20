// The sky just after the sun has gone: a burning red-orange band along the
// horizon, fading up through a pale olive green into grey-blue and deep blue
// overhead, warmest toward where the sun went down, with a few dark streaks
// of cloud low over the sea. As night comes in the warmth drains away.

const vec3 HORIZON_HOT = vec3(0.95, 0.27, 0.04);
const vec3 HORIZON_FAR = vec3(0.5, 0.11, 0.04);
const vec3 SKY_GOLD = vec3(0.72, 0.42, 0.13);
const vec3 SKY_GREEN = vec3(0.2, 0.26, 0.2);
const vec3 SKY_BLUE = vec3(0.07, 0.11, 0.21);
const vec3 SKY_HIGH = vec3(0.015, 0.025, 0.07);
const vec3 AFTERGLOW = vec3(0.45, 0.07, 0.03);
const vec3 NIGHT = vec3(0.006, 0.008, 0.02);
const vec3 CLOUD_DARK = vec3(0.07, 0.04, 0.05);
const vec3 CLOUD_RIM = vec3(0.8, 0.3, 0.1);

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

vec3 sunset_sky(vec3 dir, vec3 sun, float daylight, float time) {
	float up = max(dir.y, 0.0);
	float toward = max(dot(normalize(vec3(dir.x, 0.0, dir.z)), normalize(vec3(sun.x, 0.0, sun.z))), 0.0);
	float warm = 0.35 + 0.65 * pow(toward, 2.0);
	vec3 horizon = mix(HORIZON_FAR, HORIZON_HOT, pow(toward, 3.0));
	vec3 gold = mix(SKY_GREEN, SKY_GOLD, warm);
	vec3 sky = mix(horizon, gold, smoothstep(0.0, 0.07, up));
	sky = mix(sky, SKY_GREEN, smoothstep(0.05, 0.16, up));
	sky = mix(sky, SKY_BLUE, smoothstep(0.13, 0.32, up));
	sky = mix(sky, SKY_HIGH, smoothstep(0.3, 0.8, up));
	float azimuth = atan(dir.x, dir.z);
	float streak = sunset_fbm(vec2(azimuth * 5.0 + time * 0.003, up * 70.0));
	float band = smoothstep(0.004, 0.03, up) * smoothstep(0.16, 0.05, up);
	float cloud = smoothstep(0.55, 0.75, streak) * band;
	vec3 cloud_colour = mix(CLOUD_DARK, CLOUD_RIM, smoothstep(0.06, 0.0, up) * warm * 0.6);
	sky = mix(sky, cloud_colour, cloud * 0.8);
	vec3 night = mix(NIGHT, SKY_HIGH * 0.25, smoothstep(0.3, 0.0, up) * 0.4);
	float afterglow = smoothstep(0.12, 0.0, up) * pow(toward, 2.0) * smoothstep(0.0, 0.5, daylight);
	return mix(night, sky, daylight * daylight) + AFTERGLOW * afterglow * (1.0 - daylight);
}

vec3 sunset_sun_direction(float elevation_deg, float bearing_deg) {
	float e = radians(elevation_deg);
	float b = radians(bearing_deg);
	return vec3(sin(b) * cos(e), sin(e), -cos(b) * cos(e));
}
