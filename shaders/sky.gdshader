shader_type sky;

// Thermal sky: cold overhead, warmer toward the horizon where the sensor looks
// through more air, and the moon. The moon's sunlit side is hot rock and shows
// bright; its night side is colder than the sky behind it.

uniform vec3 sky_top_color : source_color = vec3(0.0);
uniform vec3 sky_horizon_color : source_color = vec3(0.16);
uniform float sky_curve : hint_range(0.001, 1.0) = 0.06;
uniform vec3 ground_horizon_color : source_color = vec3(0.16);
uniform vec3 ground_bottom_color : source_color = vec3(0.0);
uniform float ground_curve : hint_range(0.001, 1.0) = 0.02;
// Broken overcast lit by starlight: soft patches that drift across the glow.
uniform float cloud_contrast : hint_range(0.0, 1.0) = 0.0;
uniform float cloud_scale = 0.6;
uniform vec2 cloud_drift = vec2(0.004, 0.001);
// Cloud lit from below by the night glow: overcast reads as brighter patches.
uniform float cloud_brightness : hint_range(0.0, 0.5) = 0.045;

uniform float moon_bearing_deg : hint_range(0.0, 360.0) = 140.0;
uniform float moon_elevation_deg : hint_range(0.0, 90.0) = 22.0;
uniform float moon_diameter_deg : hint_range(0.1, 5.0) = 1.2;
uniform vec3 moon_color : source_color = vec3(0.9);
uniform float moon_phase_deg : hint_range(0.0, 180.0) = 55.0;
uniform float moon_maria : hint_range(0.0, 1.0) = 0.35;
uniform float moon_maria_scale = 3.0;
uniform float moon_tilt_deg : hint_range(-180.0, 180.0) = -35.0;
uniform float moon_craters : hint_range(0.0, 1.0) = 0.6;
uniform float moon_glow : hint_range(0.0, 2.0) = 0.35;
uniform float moon_glow_width_deg : hint_range(0.1, 30.0) = 3.0;
uniform float moon_halo : hint_range(0.0, 1.0) = 0.1;
uniform float moon_halo_width_deg : hint_range(1.0, 90.0) = 20.0;
uniform float lightning_flash : hint_range(0.0, 2.0) = 0.0;
uniform vec3 lightning_direction = vec3(0.0, 0.3, -1.0);
uniform float lightning_spread_deg : hint_range(1.0, 90.0) = 25.0;
uniform float lightning_ambient : hint_range(0.0, 1.0) = 0.25;
uniform vec3 meteor_head = vec3(0.0, 1.0, 0.0);
uniform vec3 meteor_tail = vec3(0.0, 1.0, 0.0);
uniform float meteor_glow : hint_range(0.0, 4.0) = 0.0;

const float HALF_PI = 1.5707963;
const float EDGE_SOFTNESS = 0.08;
const float CLOUD_HORIZON = 0.35;
// One display step of triangular noise, so the 8-bit sky never bands
// once the night vision gain stretches it.
const float DITHER_STEP = 1.0 / 255.0;
const float TERMINATOR_DIM = 0.55;
const vec2 MARIA_SEED = vec2(1.7, 3.1);
const float CRATER_SCALE = 3.2;
const float CRATER_FINE = 2.2;
const float CRATER_FINE_SHARE = 0.6;
const float CRATER_SEED = 19.1;
const float CRATER_MIN = 0.12;
const float CRATER_MAX = 0.4;
const float CRATER_RIM = 1.2;
const float DISPLAY_GAMMA = 2.2;
const float DITHER_SEED = 431.0;
const float DITHER_OFFSET = 17.0;
const float CLOUD_DETAIL = 2.3;
const vec2 CLOUD_SEED = vec2(5.2, 1.3);
const float CLOUD_DETAIL_SHARE = 0.35;
const float CLOUD_FILL = 0.15;
const float METEOR_WIDTH = 0.0012;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(0.0, 1.0, fract(p));
	return mix(
		mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

vec3 atmosphere(vec3 direction) {
	float v_angle = acos(clamp(direction.y, -1.0, 1.0));
	float c = 1.0 - v_angle / HALF_PI;
	if (direction.y >= 0.0) {
		return mix(sky_horizon_color, sky_top_color, clamp(1.0 - pow(1.0 - c, 1.0 / sky_curve), 0.0, 1.0));
	}
	float g = -c;
	return mix(ground_horizon_color, ground_bottom_color, clamp(1.0 - pow(1.0 - g, 1.0 / ground_curve), 0.0, 1.0));
}

vec3 moon_direction() {
	float bearing = radians(moon_bearing_deg);
	float elevation = radians(moon_elevation_deg);
	return vec3(sin(bearing) * cos(elevation), sin(elevation), -cos(bearing) * cos(elevation));
}

float cloud_cover(vec3 direction) {
	vec2 plane = direction.xz / max(direction.y, CLOUD_HORIZON) * cloud_scale + TIME * cloud_drift;
	float n = mix(value_noise(plane), value_noise(plane * CLOUD_DETAIL + CLOUD_SEED), CLOUD_DETAIL_SHARE);
	return 1.0 + (n - 0.5) * 2.0 * cloud_contrast * smoothstep(0.0, CLOUD_HORIZON, direction.y);
}

float cloud_body(vec3 direction) {
	vec2 plane = direction.xz / max(direction.y, CLOUD_HORIZON) * cloud_scale + TIME * cloud_drift;
	float n = mix(value_noise(plane), value_noise(plane * CLOUD_DETAIL + CLOUD_SEED), CLOUD_DETAIL_SHARE);
	float thickness = smoothstep(1.0 - cloud_contrast, 1.2 - cloud_contrast * 0.6, n + cloud_contrast * CLOUD_FILL);
	return thickness * cloud_contrast * smoothstep(0.0, CLOUD_HORIZON, direction.y);
}

// Pocked surface: each cell holds one crater, a dark floor with a bright rim.
float craters(vec2 p) {
	vec2 cell = floor(p);
	float marks = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = cell + vec2(float(x), float(y));
			vec2 centre = c + vec2(hash12(c), hash12(c + CRATER_SEED));
			float size = mix(CRATER_MIN, CRATER_MAX, hash12(c - CRATER_SEED));
			float d = length(p - centre) / size;
			marks += (1.0 - smoothstep(0.6, 1.0, d)) - smoothstep(0.85, 1.0, d) * (1.0 - smoothstep(1.0, 1.15, d)) * CRATER_RIM;
		}
	}
	return clamp(marks, -1.0, 1.0);
}

float meteor(vec3 direction) {
	if (meteor_glow <= 0.0) {
		return 0.0;
	}
	vec3 along = meteor_head - meteor_tail;
	float share = clamp(dot(direction - meteor_tail, along) / max(dot(along, along), 1e-8), 0.0, 1.0);
	float gap = length(direction - (meteor_tail + along * share)) / METEOR_WIDTH;
	return meteor_glow * share * share * exp(-gap * gap);
}

void sky() {
	vec3 colour = atmosphere(EYEDIR) * cloud_cover(EYEDIR) + vec3(cloud_body(EYEDIR) * cloud_brightness);

	vec3 toward = moon_direction();
	float off_moon = degrees(acos(clamp(dot(EYEDIR, toward), -1.0, 1.0)));
	colour += moon_color * (
		moon_glow * exp(-off_moon / moon_glow_width_deg)
		+ moon_halo * exp(-off_moon / moon_halo_width_deg)
	);
	vec3 right = normalize(cross(toward, vec3(0.0, 1.0, 0.0)));
	vec3 up = cross(right, toward);
	float radius = radians(moon_diameter_deg) * 0.5;
	vec2 disc = vec2(dot(EYEDIR, right), dot(EYEDIR, up)) / radius;
	float from_centre = length(disc);
	if (dot(EYEDIR, toward) > 0.0 && from_centre < 1.0 + EDGE_SOFTNESS) {
		vec3 surface = vec3(disc, sqrt(max(1.0 - from_centre * from_centre, 0.0)));
		float phase = radians(moon_phase_deg);
		float tilt = radians(moon_tilt_deg);
		vec3 sun = vec3(sin(phase) * cos(tilt), sin(phase) * sin(tilt), cos(phase));
		float lit = smoothstep(-0.02, 0.12, dot(surface, sun)) * mix(TERMINATOR_DIM, 1.0, smoothstep(0.0, 0.5, dot(surface, sun)));
		float maria = 1.0 - moon_maria * smoothstep(0.35, 0.75, value_noise(disc * moon_maria_scale + MARIA_SEED));
		maria *= 1.0 - moon_craters * (craters(disc * CRATER_SCALE) + craters(disc * CRATER_SCALE * CRATER_FINE + MARIA_SEED) * CRATER_FINE_SHARE);
		float coverage = 1.0 - smoothstep(1.0 - EDGE_SOFTNESS, 1.0 + EDGE_SOFTNESS, from_centre);
		colour += moon_color * lit * maria * coverage;
	}
	float off_bolt = degrees(acos(clamp(dot(EYEDIR, normalize(lightning_direction)), -1.0, 1.0)));
	colour += lightning_flash * (lightning_ambient + exp(-off_bolt / lightning_spread_deg));
	colour += vec3(meteor(EYEDIR));
	vec2 cell = FRAGCOORD.xy + fract(TIME) * DITHER_SEED;
	float dither = (hash12(cell) + hash12(cell + DITHER_OFFSET) - 1.0) * DITHER_STEP;
	COLOR = pow(max(pow(colour, vec3(1.0 / DISPLAY_GAMMA)) + dither, vec3(0.0)), vec3(DISPLAY_GAMMA));
}
