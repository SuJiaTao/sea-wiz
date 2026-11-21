shader_type spatial;
render_mode unshaded, shadows_disabled;

#include "res://shaders/sunset.gdshaderinc"

// The sea under a low sun. Long swells really lift the water, with crests a
// little sharper than their troughs. On top, the same wave normal map the
// game's ocean uses crosses in several sheets for the fine surface. Where
// that detail is too fine for a pixel, its mipmaps average out, and how much
// they flattened is kept as roughness, so far water stays matte. Away from
// the sun the water mirrors cool slate sky; toward it, the glints make a thin
// broken column at the horizon that fans out into twinkling pin points near us.

uniform float sun_elevation_deg = 3.0;
uniform float sun_bearing_deg = 270.0;
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
uniform vec3 deep_water : source_color = vec3(0.012, 0.024, 0.045);
uniform sampler2D wave_normals : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float swell_height = 0.18;
uniform float detail_strength = 0.5;
uniform float wind_bearing_deg = 60.0;
uniform float glitter_sharpness = 4000.0;
uniform float glitter_strength = 14.0;

const int SWELLS = 4;
const float SWELL_LENGTHS[4] = float[](78.0, 51.0, 34.0, 22.0);
const float SWELL_SHARES[4] = float[](1.0, 0.6, 0.35, 0.2);
const float SWELL_ANGLES[4] = float[](0.0, 0.5, -0.45, 0.9);
// Gerstner steepness: how far each crest leans in toward a point.
const float SWELL_STEEPNESS = 0.55;
const float GRAVITY = 9.8;
// Swells settle flat well before the horizon, where the water drops just
// under the far sheet so the two meet without a seam.
const float SWELL_FADE_START = 250.0;
const float SWELL_FADE_END = 650.0;
const float FAR_DROP = 1.0;

const int DETAIL_LAYERS = 4;
const float DETAIL_TILES[4] = float[](40.0, 14.0, 6.0, 2.5);
const float DETAIL_ANGLES[4] = float[](0.3, 0.0, 0.65, -0.55);
const float DETAIL_SPEEDS[4] = float[](2.6, 1.9, 1.4, 1.0);
const float DETAIL_SHARES[4] = float[](0.7, 1.0, 0.8, 0.6);
const float DETAIL_STRETCH = 0.45;

const vec3 GLINT_COLOUR = vec3(1.0, 0.62, 0.3);
// The glitter dies as the last of the disc slips under.
const float SUN_RADIUS_DEG = 0.6;
// Even at a grazing angle the sea stays a little darker than the sky, so the
// horizon line holds and the sun visibly sinks into it.
const float HORIZON_REFLECTION = 0.5;
const float ROUGH_SHADOWING = 0.35;
const float MASKING = 0.5;
const float REFLECTION_SPREAD = 0.02;
const int SKY_TAPS = 4;
// The far glitter path is much taller than it is wide.
const float COLUMN_NARROWING = 0.002;
const float COLUMN_FALLOFF = 0.3;
const float MAX_VARIANCE = 0.03;
// Pin-point glints: each small patch of water carries one tiny facet tipped
// at random, and lights up only when that facet lines up with the sun.
const float FACET_CELL = 0.3;
const float FACET_TILT = 0.18;
const float FACET_AIM = 0.045;
const float FACET_SWAY = 0.35;
const float FACET_SWAY_RATE = 2.2;
const float FACET_MIN_PIXELS = 3.0;
const float SPARKLE_STRENGTH = 45.0;
// Near water keeps only a faint glow under its pin points.
const float NEAR_GLOW = 0.12;
// Away from the sun the water mostly mirrors cooler, dimmer sky from higher
// up, so it reads slate blue; only a narrow band toward the sun stays warm.
const vec3 COOL_REFLECTION = vec3(0.45, 0.62, 0.9);
const float WARM_FOCUS = 400.0;
// Out toward the horizon the glitter column breaks into bright blobs.
const float BLOB_WIDTH = 40.0;
const float BLOB_ROWS = 3000.0;
const float BLOB_DRIFT = 0.8;

varying vec2 rest_xz;
varying vec3 world_position;

float swell_fade(vec2 xz, vec3 eye) {
	return 1.0 - smoothstep(SWELL_FADE_START, SWELL_FADE_END, distance(xz, eye.xz));
}

vec2 swell_heading(int i) {
	float angle = radians(wind_bearing_deg) + SWELL_ANGLES[i];
	return vec2(sin(angle), -cos(angle));
}

float swell_phase(int i, vec2 xz, out float k) {
	k = TAU / SWELL_LENGTHS[i];
	return k * dot(swell_heading(i), xz) - sqrt(GRAVITY * k) * TIME;
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	rest_xz = world.xz;
	float fade = swell_fade(world.xz, CAMERA_POSITION_WORLD);
	vec3 lift = vec3(0.0);
	for (int i = 0; i < SWELLS; i++) {
		float k;
		float phase = swell_phase(i, world.xz, k);
		float a = swell_height * SWELL_SHARES[i];
		vec2 lean = swell_heading(i) * SWELL_STEEPNESS / (k * float(SWELLS)) * cos(phase) * SWELL_SHARES[i];
		lift += vec3(lean.x, a * sin(phase), lean.y);
	}
	world += lift * fade;
	world.y -= FAR_DROP * (1.0 - fade);
	world_position = world;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
}

vec2 swell_slope(vec2 xz, float fade) {
	vec2 s = vec2(0.0);
	for (int i = 0; i < SWELLS; i++) {
		float k;
		float phase = swell_phase(i, xz, k);
		float a = swell_height * SWELL_SHARES[i];
		// Leaning crests pinch the slope near the top and spread it in the trough.
		float pinch = 1.0 - SWELL_STEEPNESS / float(SWELLS) * SWELL_SHARES[i] * sin(phase);
		s += swell_heading(i) * k * a * cos(phase) / max(pinch, 0.2);
	}
	return s * fade;
}

// One sheet of the wave map, stretched across its heading so ripples run in
// long lines. Returns the slope and how much the mipmaps flattened it.
vec3 detail_layer(vec2 xz, int i) {
	float angle = radians(wind_bearing_deg) + DETAIL_ANGLES[i];
	vec2 heading = vec2(sin(angle), -cos(angle));
	vec2 across = vec2(-heading.y, heading.x);
	vec2 uv = vec2(dot(xz, across) * DETAIL_STRETCH, dot(xz, heading) - DETAIL_SPEEDS[i] * TIME) / DETAIL_TILES[i];
	vec3 n = texture(wave_normals, uv).xyz * 2.0 - 1.0;
	float kept = clamp(length(n), 0.05, 1.0);
	vec2 local = n.xy / max(n.z, 0.2) * vec2(DETAIL_STRETCH, 1.0);
	float strength = detail_strength * DETAIL_SHARES[i];
	// Toksvig: a short averaged normal means slopes were lost to filtering.
	float lost = (1.0 - kept) / kept;
	return vec3((across * local.x + heading * local.y) * strength, lost * strength * strength);
}

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

// Returns the sparkle light, and in y how far the sparkles are resolvable here.
vec2 sparkles(vec2 xz, vec2 slope, vec3 view, vec3 sun) {
	// Cells never shrink below a few pixels, so far off each one stands for a
	// whole patch of facets and still shows as a single pin point.
	vec2 pixel2 = fwidth(xz);
	float pixel = max(length(pixel2), 1e-4);
	float cell_size = max(FACET_CELL, pixel * FACET_MIN_PIXELS);
	float resolvable = smoothstep(FACET_CELL * 40.0, FACET_CELL * 8.0, cell_size);
	if (resolvable <= 0.0) {
		return vec2(0.0);
	}
	vec3 half_way = normalize(sun - view);
	vec2 wanted = -half_way.xz / max(half_way.y, 0.05);
	vec2 cell = floor(xz / cell_size);
	vec2 within = fract(xz / cell_size);
	vec2 seed = vec2(hash(cell), hash(cell + 17.3));
	vec2 sway = vec2(sin(TIME * FACET_SWAY_RATE + seed.x * TAU), cos(TIME * FACET_SWAY_RATE * 0.8 + seed.y * TAU)) * FACET_SWAY;
	vec2 facet = slope + (seed - 0.5 + sway) * 2.0 * FACET_TILT;
	vec2 miss = wanted - facet;
	float aimed = exp(-dot(miss, miss) / (2.0 * FACET_AIM * FACET_AIM));
	vec2 centre = vec2(hash(cell + 3.1), hash(cell + 9.7)) * 0.6 + 0.2;
	float from_centre = length((within - centre) * cell_size / max(pixel2, vec2(1e-4)));
	float spot = exp(-from_centre * from_centre * 0.25);
	return vec2(aimed * spot * resolvable, resolvable);
}

void fragment() {
	vec3 sun = sunset_sun_direction(sun_elevation_deg, sun_bearing_deg);
	vec3 eye = CAMERA_POSITION_WORLD;
	vec3 view = normalize(world_position - eye);
	vec2 slope = swell_slope(rest_xz, swell_fade(rest_xz, eye));
	float variance = 0.0;
	for (int i = 0; i < DETAIL_LAYERS; i++) {
		vec3 layer = detail_layer(rest_xz, i);
		slope += layer.xy;
		variance += layer.z;
	}
	// Open sea never gets rougher than a fresh breeze makes it.
	variance = min(variance, MAX_VARIANCE);
	float spread = sqrt(variance);
	vec3 normal = normalize(vec3(-slope.x, 1.0, -slope.y));
	vec3 mirrored = reflect(view, normal);
	mirrored.y = abs(mirrored.y);

	// Each facet sees a patch of sky: the rougher, the further it reaches.
	float reach = REFLECTION_SPREAD + 2.0 * spread;
	vec3 sky = vec3(0.0);
	for (int i = 0; i < SKY_TAPS; i++) {
		float offset = (float(i) / float(SKY_TAPS - 1) - 0.3) * reach;
		vec3 tap = normalize(vec3(mirrored.x, abs(mirrored.y + offset), mirrored.z));
		sky += sunset_sky(tap, sun, daylight, TIME, false);
	}
	sky /= float(SKY_TAPS);
	vec2 flat_mirror = normalize(mirrored.xz);
	vec2 flat_sun = normalize(sun.xz);
	float warm = pow(max(dot(flat_mirror, flat_sun), 0.0), WARM_FOCUS);
	float light = dot(sky, vec3(0.299, 0.587, 0.114));
	sky = mix(light * COOL_REFLECTION, sky, warm);

	// Rough water seen almost edge-on hides its own far faces and turns its
	// near faces toward us, which reflect less, so it reads darker than the sky.
	float grazing = max(-view.y, 0.0);
	float hidden = smoothstep(0.0, 1.0, spread / max(grazing, 0.001) * MASKING);
	float facing_us = max(dot(-view, normal), mix(0.0, spread * 2.0, hidden));
	float fresnel = 0.04 + HORIZON_REFLECTION * pow(1.0 - facing_us, 5.0);
	fresnel *= 1.0 - ROUGH_SHADOWING * hidden;

	// Glints: a pin point where a facet tips exactly toward the sun, widening
	// into a tall column far off where the facets are too small to draw.
	float above = smoothstep(-SUN_RADIUS_DEG, SUN_RADIUS_DEG, sunset_elevation(sun));
	float base = 1.0 / glitter_sharpness;
	float tall = base + 4.0 * variance;
	// Tipping a facet sideways barely swings its reflection when seen edge-on,
	// so the column is a thin line at the horizon and fans out toward us.
	float wide = base + 4.0 * variance * (COLUMN_NARROWING + grazing * grazing);
	float rise = mirrored.y - sun.y;
	float aside = flat_mirror.x * flat_sun.y - flat_mirror.y * flat_sun.x;
	float lobe = exp(-0.5 * (rise * rise / tall + aside * aside / wide)) * pow(base * base / (tall * wide), COLUMN_FALLOFF);
	vec2 out_to = rest_xz - eye.xz;
	vec2 heading = normalize(view.xz);
	float along = max(dot(out_to, heading), 1.0);
	float across = dot(out_to, vec2(-heading.y, heading.x));
	float blobs = smoothstep(0.45, 0.62, sunset_fbm(vec2(across / along * BLOB_WIDTH, BLOB_ROWS / along + TIME * BLOB_DRIFT)));
	lobe *= mix(1.0, blobs * 2.5, smoothstep(0.0, 0.02, spread));
	vec2 sparkle = sparkles(rest_xz, slope, view, sun);
	float glint = (lobe * glitter_strength * mix(1.0, NEAR_GLOW, sparkle.y) + sparkle.x * SPARKLE_STRENGTH) * above * daylight;
	ALBEDO = mix(deep_water, sky, fresnel) + GLINT_COLOUR * glint;
}
