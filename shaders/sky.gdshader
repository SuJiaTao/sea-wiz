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
// Rain clouds ray-marched at real heights in three layers: ragged scud low
// down, the main heaped deck around a kilometre up, a thin sheet above.
// Each layer: base metres, thickness metres, feature size metres, sparseness.
uniform vec4 scud_layer = vec4(450.0, 350.0, 650.0, 0.14);
uniform vec4 deck_layer = vec4(900.0, 1800.0, 1800.0, 0.0);
uniform vec4 sheet_layer = vec4(3200.0, 450.0, 5200.0, 0.06);
uniform float cloud_fade_m = 9000.0;
// Low storm ceiling that rolls in ahead of rain: an unbroken grey deck with a
// lumpy, pouched underside, dark lumps split by lighter creases.
uniform float overcast : hint_range(0.0, 1.0) = 0.0;
uniform float overcast_base_m = 1400.0;
uniform float overcast_cell_m = 560.0;
uniform float overcast_depth_m = 320.0;
uniform float overcast_dark : hint_range(0.0, 0.3) = 0.015;
uniform float overcast_light : hint_range(0.0, 0.5) = 0.1;
uniform float camera_height_m = 18.0;
uniform float cloud_ambient : hint_range(0.0, 0.5) = 0.05;
uniform float cloud_moonlit : hint_range(0.0, 1.0) = 0.3;

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
const int SCUD_STEPS = 5;
const int DECK_STEPS = 14;
const int SHEET_STEPS = 3;
const float SHEET_DENSITY = 0.35;
const float CLOUD_EXTINCTION = 0.009;
const float CLOUD_BOTTOM_ROUND = 0.22;
const float CLOUD_BOTTOM_REACH = 0.3;
const float CLOUD_TOP_ROUND = 0.28;
const float CLUSTER_SCALE = 4.0;
const float CLUSTER_SHARE = 0.35;
const float EROSION_SCALE = 3.7;
const float EROSION_SHARE = 0.16;
const float POWDER = 2.0;
const vec2 CLOUD_SLICE_SHIFT = vec2(7.3, 11.9);
const float POUCH_SEED = 41.3;
const int BILLOW_OCTAVES = 3;
const float BILLOW_GAIN = 0.45;
const float BILLOW_LACUNARITY = 2.3;
const float BILLOW_SHARE = 0.8;
const float WARP_SCALE = 0.35;
const float WARP_REACH = 1.4;
const float SAG_FLOOR = 0.45;
const float SWELL_SCALE = 0.18;
const float SWELL_SHARE = 0.15;
const int RELIEF_STEPS = 14;
const float RELIEF_PROBE = 0.08;
const float RELIEF_LIGHT_DROP = 0.35;
const float RELIEF_LIGHT_SHARE = 0.75;
const float RELIEF_WRAP = 0.5;
const float RELIEF_SAG_SHARE = 0.3;
const float RELIEF_CREVICE_DARK = 0.55;
const float OVERCAST_MOON_BLOCK = 0.85;
const float CLOUD_HORIZON_FADE = 0.14;
const float CLOUD_RAIN_FROM = 0.3;
const float CLOUD_RAIN_FULL = 0.85;
const float CLOUD_THRESHOLD_CLEAR = 0.78;
const float CLOUD_THRESHOLD_STORM = 0.38;
const float CLOUD_LIGHT_NEAR = 0.15;
const float CLOUD_LIGHT_FAR = 0.4;
const float CLOUD_MIN_RISE = 0.015;
const vec2 CLOUD_OCTAVE_SHIFT = vec2(3.7, 1.9);
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

float cloud_noise(vec2 p) {
	float total = 0.0;
	float weight = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		total += value_noise(p) * weight;
		p = p * 2.03 + CLOUD_OCTAVE_SHIFT;
		weight *= 0.5;
	}
	return total / 0.9375;
}

float rain_cover() {
	return smoothstep(CLOUD_RAIN_FROM, CLOUD_RAIN_FULL, cloud_contrast);
}

// Two noise slices blended by height, so the shape changes as it rises
// and the clouds billow instead of being the same outline top to bottom.
float cloud_noise3(vec3 p) {
	float slice = floor(p.y);
	float blend = smoothstep(0.0, 1.0, p.y - slice);
	return mix(
		cloud_noise(p.xz + slice * CLOUD_SLICE_SHIFT),
		cloud_noise(p.xz + (slice + 1.0) * CLOUD_SLICE_SHIFT),
		blend
	);
}

float cloud_density(vec3 point, vec4 layer, float cover) {
	float height = (point.y - layer.x) / layer.y;
	if (height < 0.0 || height > 1.0) {
		return 0.0;
	}
	vec3 p = vec3(point.x, point.y, point.z) / layer.z;
	p.xz += TIME * cloud_drift;
	float cluster = value_noise(p.xz / CLUSTER_SCALE);
	float threshold = mix(CLOUD_THRESHOLD_CLEAR, CLOUD_THRESHOLD_STORM, cover) + layer.w;
	threshold += CLOUD_BOTTOM_ROUND * (1.0 - smoothstep(0.0, CLOUD_BOTTOM_REACH, height));
	threshold += CLOUD_TOP_ROUND * smoothstep(0.35, 1.0, height);
	threshold += (0.5 - cluster) * CLUSTER_SHARE;
	float body = cloud_noise3(p) - threshold;
	body -= cloud_noise(p.xz * EROSION_SCALE + p.y) * EROSION_SHARE * (1.0 - smoothstep(0.0, 0.25, body));
	return max(body, 0.0);
}

void march_layer(vec3 direction, vec4 layer, int steps, float strength, float cover, float jitter, inout float clear, inout float light) {
	float enter = (layer.x - camera_height_m) / direction.y;
	float leave = (layer.x + layer.y - camera_height_m) / direction.y;
	float stride = (leave - enter) / float(steps);
	float fade = exp(-enter / cloud_fade_m) * smoothstep(CLOUD_MIN_RISE, CLOUD_HORIZON_FADE, direction.y);
	for (int i = 0; i < steps; i++) {
		if (clear < 0.02) {
			return;
		}
		vec3 point = vec3(0.0, camera_height_m, 0.0) + direction * (enter + stride * (float(i) + jitter));
		float density = cloud_density(point, layer, cover) * strength;
		if (density <= 0.0) {
			continue;
		}
		float shade = cloud_density(point + vec3(0.0, layer.y * CLOUD_LIGHT_NEAR, 0.0), layer, cover)
			+ cloud_density(point + vec3(0.0, layer.y * CLOUD_LIGHT_FAR, 0.0), layer, cover);
		float moonlit = exp(-shade * strength * CLOUD_EXTINCTION * layer.y * CLOUD_LIGHT_NEAR);
		float powder = 1.0 - exp(-density * CLOUD_EXTINCTION * stride * POWDER);
		float absorbed = (1.0 - exp(-density * CLOUD_EXTINCTION * stride)) * fade;
		light += clear * absorbed * (cloud_ambient + cloud_moonlit * moonlit * powder * (1.0 - overcast * OVERCAST_MOON_BLOCK));
		clear *= 1.0 - absorbed;
	}
}

// Billows hanging from the deck, after the Perlin-Worley clouds of Horizon
// Zero Dawn: inverted cell noise gives rounded lumps, stacked in octaves so
// each lump carries smaller ones, and a warp bends them out of round.
float billow(vec2 p) {
	vec2 cell = floor(p);
	float nearest = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = cell + vec2(float(x), float(y));
			vec2 centre = c + vec2(hash12(c), hash12(c + POUCH_SEED));
			nearest = min(nearest, length(p - centre));
		}
	}
	return 1.0 - nearest * nearest;
}

float billow_stack(vec2 p) {
	float heap = 0.0;
	float weight = 1.0;
	float total = 0.0;
	for (int i = 0; i < BILLOW_OCTAVES; i++) {
		heap += billow(p) * weight;
		total += weight;
		weight *= BILLOW_GAIN;
		p = p * BILLOW_LACUNARITY + CLOUD_OCTAVE_SHIFT;
	}
	return heap / total;
}

// How far a point on the storm ceiling hangs down, 0 to 1: warped billows
// riding a slow swell, so the lumps come in uneven rolls and clusters.
float ceiling_sag(vec2 p) {
	vec2 bend = vec2(value_noise(p * WARP_SCALE), value_noise(p * WARP_SCALE + CLOUD_SLICE_SHIFT)) - 0.5;
	vec2 q = p + bend * WARP_REACH;
	float swell = value_noise(p * SWELL_SCALE);
	float lumps = billow_stack(q);
	return smoothstep(SAG_FLOOR, 1.0, lumps * BILLOW_SHARE + swell * SWELL_SHARE);
}

// The storm ceiling seen from below as a hanging relief: the ray climbs from
// the lowest pouch to the ceiling top and stops where it meets the cloud, so
// near pouches hide the ones behind them, then the surface is lit from the
// moon's side of the horizon. Returns brightness and coverage.
vec2 overcast_ceiling(vec3 direction, float jitter) {
	if (overcast <= 0.0 || direction.y < CLOUD_MIN_RISE) {
		return vec2(0.0);
	}
	float top = overcast_base_m;
	float bottom = overcast_base_m - overcast_depth_m;
	float enter = (bottom - camera_height_m) / direction.y;
	float leave = (top - camera_height_m) / direction.y;
	vec2 drift = TIME * cloud_drift * (deck_layer.z / overcast_cell_m);
	float stride = (leave - enter) / float(RELIEF_STEPS);
	float reach = leave;
	float sag = 0.0;
	float previous_gap = -1.0;
	for (int i = 0; i < RELIEF_STEPS; i++) {
		float along = enter + stride * (float(i) + jitter);
		vec3 point = direction * along + vec3(0.0, camera_height_m, 0.0);
		float hanging = ceiling_sag(point.xz / overcast_cell_m + drift);
		float gap = point.y - (top - overcast_depth_m * hanging);
		if (gap >= 0.0) {
			float back = previous_gap < 0.0 ? gap / max(gap - previous_gap, 1e-4) : 0.0;
			reach = along - stride * back;
			sag = hanging;
			break;
		}
		previous_gap = gap;
	}
	vec2 p = direction.xz * reach / overcast_cell_m + drift;
	float rise_x = ceiling_sag(p + vec2(RELIEF_PROBE, 0.0)) - ceiling_sag(p - vec2(RELIEF_PROBE, 0.0));
	float rise_z = ceiling_sag(p + vec2(0.0, RELIEF_PROBE)) - ceiling_sag(p - vec2(0.0, RELIEF_PROBE));
	float slope = overcast_depth_m / (overcast_cell_m * RELIEF_PROBE * 2.0);
	vec3 normal = normalize(vec3(rise_x * slope, -1.0, rise_z * slope));
	vec3 moon = moon_direction();
	vec3 glow_from = normalize(vec3(moon.x, -RELIEF_LIGHT_DROP, moon.z));
	float lit = clamp((dot(normal, glow_from) + RELIEF_WRAP) / (1.0 + RELIEF_WRAP), 0.0, 1.0);
	float tucked = mix(RELIEF_CREVICE_DARK, 1.0, sag);
	float level = mix(overcast_dark, overcast_light, clamp(lit * RELIEF_LIGHT_SHARE + sag * RELIEF_SAG_SHARE, 0.0, 1.0)) * tucked;
	float distance_fade = exp(-reach / cloud_fade_m) * smoothstep(CLOUD_MIN_RISE, CLOUD_HORIZON_FADE, direction.y);
	return vec2(level, overcast * distance_fade);
}

// Front-to-back through the layers, nearest first: returns light and coverage.
vec2 cloud_deck(vec3 direction, float jitter) {
	float cover = rain_cover();
	if (cover <= 0.0 || direction.y < CLOUD_MIN_RISE) {
		return vec2(0.0);
	}
	float clear = 1.0;
	float light = 0.0;
	march_layer(direction, scud_layer, SCUD_STEPS, 1.0, cover, jitter, clear, light);
	march_layer(direction, deck_layer, DECK_STEPS, 1.0, cover, jitter, clear, light);
	march_layer(direction, sheet_layer, SHEET_STEPS, SHEET_DENSITY, cover, jitter, clear, light);
	return vec2(light, 1.0 - clear);
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
	float jitter = hash12(FRAGCOORD.xy + fract(TIME) * DITHER_SEED);
	vec2 ceiling = overcast_ceiling(EYEDIR, jitter);
	colour = colour * (1.0 - ceiling.y) + vec3(ceiling.x * ceiling.y);
	vec2 deck = cloud_deck(EYEDIR, jitter);
	colour = colour * (1.0 - deck.y) + vec3(deck.x);

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
