shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// Open ocean as the intensifier sees it: a dark water body that mirrors the
// glowing sky. A spectrum of wind waves sets the surface normal; each wave
// fades out once it is smaller than a pixel, so the far sea settles into a
// clean mirror of the horizon instead of shimmering.

uniform float base_level : hint_range(0.0, 0.5) = 0.03;
uniform float sky_horizon_level : hint_range(0.0, 1.0) = 0.16;
uniform float sky_top_level : hint_range(0.0, 1.0) = 0.07;
uniform float sky_curve : hint_range(0.001, 1.0) = 0.25;
uniform float reflectance : hint_range(0.0, 0.2) = 0.02;
uniform float wind_bearing_deg : hint_range(0.0, 360.0) = 60.0;
uniform float wave_spread : hint_range(0.0, 3.1416) = 1.1;
uniform float longest_wave = 70.0;
uniform float shortest_wave = 0.6;
uniform float steepness : hint_range(0.0, 1.0) = 0.22;
uniform float roughness : hint_range(0.0, 1.0) = 0.0;
uniform float storm_steepness : hint_range(0.0, 2.0) = 1.4;
uniform float foam_level : hint_range(0.0, 1.0) = 0.45;
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.4;
uniform float foam_scale = 0.35;
uniform float moon_bearing_deg : hint_range(0.0, 360.0) = 140.0;
uniform float moon_elevation_deg : hint_range(0.0, 90.0) = 22.0;
uniform float moon_path : hint_range(0.0, 2.0) = 0.35;
uniform float moon_path_sharpness : hint_range(1.0, 2000.0) = 60.0;
uniform float glitter : hint_range(0.0, 4.0) = 1.2;
uniform float glitter_sharpness : hint_range(1.0, 4000.0) = 900.0;
uniform float lightning_flash : hint_range(0.0, 2.0) = 0.0;
uniform float lightning_reflection : hint_range(0.0, 1.0) = 0.3;

const int WAVES = 14;
const float GRAVITY = 9.81;
const float DISPLAY_GAMMA = 2.2;
const float DITHER_STEP = 1.0 / 255.0;
const float PIXELS_PER_WAVE = 3.0;
const float SPREAD_SEED = 12.9898;
const float PHASE_SEED = 78.233;
const float FOAM_FOOTPRINT = 2.0;
const float CREST_GAIN = 1.6;

varying vec3 world_pos;

float hash11(float n) {
	return fract(sin(n) * 43758.5453);
}

float hash21(vec2 p) {
	p = fract(p * vec2(233.34, 851.73));
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

vec3 moon_direction() {
	float bearing = radians(moon_bearing_deg);
	float elevation = radians(moon_elevation_deg);
	return vec3(sin(bearing) * cos(elevation), sin(elevation), -cos(bearing) * cos(elevation));
}

float sky_level(vec3 ray) {
	float c = 1.0 - acos(clamp(abs(ray.y), 0.0, 1.0)) / (PI * 0.5);
	return mix(sky_horizon_level, sky_top_level, clamp(1.0 - pow(1.0 - c, 1.0 / sky_curve), 0.0, 1.0));
}

// Sum of deep-water waves. xy: surface slope, z: crest height in -1..1.
vec3 waves(vec2 xz, float footprint) {
	float wind = radians(wind_bearing_deg);
	float sharp = steepness * (1.0 + roughness * storm_steepness);
	vec2 slope = vec2(0.0);
	float crest = 0.0;
	float weight = 0.0;
	for (int i = 0; i < WAVES; i++) {
		float share = float(i) / float(WAVES - 1);
		float wavelength = longest_wave * pow(shortest_wave / longest_wave, share);
		float resolved = smoothstep(footprint * PIXELS_PER_WAVE, footprint * PIXELS_PER_WAVE * 2.0, wavelength);
		if (resolved <= 0.0) {
			continue;
		}
		float k = TAU / wavelength;
		float angle = wind + (hash11(float(i) * SPREAD_SEED) - 0.5) * wave_spread;
		vec2 heading = vec2(sin(angle), -cos(angle));
		float phase = dot(xz, heading) * k - sqrt(GRAVITY * k) * TIME + hash11(float(i) * PHASE_SEED) * TAU;
		float amplitude = sharp / k / float(WAVES) * 4.0 * resolved;
		slope += heading * k * amplitude * cos(phase);
		crest += sin(phase) * resolved * (1.0 - share);
		weight += resolved * (1.0 - share);
	}
	return vec3(slope, crest / max(weight, 1e-3));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 view_ray = normalize(world_pos - CAMERA_POSITION_WORLD);
	float footprint = length(fwidth(world_pos.xz));
	vec3 surface = waves(world_pos.xz, footprint);
	vec3 normal = normalize(vec3(-surface.x, 1.0, -surface.y));
	vec3 bounce = reflect(view_ray, normal);
	bounce.y = abs(bounce.y);

	float facing = clamp(dot(normal, -view_ray), 0.0, 1.0);
	float fresnel = reflectance + (1.0 - reflectance) * pow(1.0 - facing, 5.0);
	float v = mix(base_level, sky_level(bounce), fresnel);

	float toward_moon = max(dot(bounce, moon_direction()), 0.0);
	v += pow(toward_moon, moon_path_sharpness) * moon_path * fresnel;
	v += pow(toward_moon, glitter_sharpness) * glitter;

	float breakup = value_noise(world_pos.xz * foam_scale + TIME * 0.2) * value_noise(world_pos.xz * foam_scale * 2.7 - TIME * 0.15);
	float whitecap = smoothstep(foam_threshold, 1.0, surface.z * CREST_GAIN) * smoothstep(0.1, 0.4, breakup);
	v += whitecap * foam_level * (0.15 + roughness) * smoothstep(FOAM_FOOTPRINT, FOAM_FOOTPRINT * 0.25, footprint);

	v = max(v, 0.0) + lightning_flash * lightning_reflection;
	vec2 cell = FRAGCOORD.xy + fract(TIME) * 431.0;
	v += (hash21(cell) + hash21(cell + 17.0) - 1.0) * DITHER_STEP;
	ALBEDO = vec3(pow(max(v, 0.0), DISPLAY_GAMMA));
}
