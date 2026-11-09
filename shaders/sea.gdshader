shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// Open ocean as the intensifier sees it: a dark water body that mirrors the
// glowing sky. A spectrum of wind waves sets the surface normal; each wave
// fades out once it is smaller than a pixel, so the far sea settles into a
// clean mirror of the horizon instead of shimmering.

uniform float base_level : hint_range(0.0, 0.5) = 0.03;
uniform float sky_horizon_level : hint_range(0.0, 1.0) = 0.16;
uniform float sky_top_level : hint_range(0.0, 1.0) = 0.09;
uniform float sky_curve : hint_range(0.001, 1.0) = 0.12;
uniform float reflectance : hint_range(0.0, 0.2) = 0.06;
uniform float wind_bearing_deg : hint_range(0.0, 360.0) = 60.0;
uniform float longest_wave = 30.0;
uniform float gustiness : hint_range(0.0, 1.0) = 0.55;
uniform float steepness : hint_range(0.0, 1.0) = 0.14;
uniform float roughness : hint_range(0.0, 1.0) = 0.0;
uniform float storm_steepness : hint_range(0.0, 2.0) = 1.4;
uniform float foam_level : hint_range(0.0, 1.0) = 0.45;
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.45;
uniform float foam_scale = 0.12;
uniform float moon_bearing_deg : hint_range(0.0, 360.0) = 140.0;
uniform float moon_elevation_deg : hint_range(0.0, 90.0) = 22.0;
uniform float moon_path : hint_range(0.0, 2.0) = 0.25;
uniform float moon_path_sharpness : hint_range(1.0, 2000.0) = 25.0;
uniform float glitter : hint_range(0.0, 4.0) = 1.6;
uniform float glitter_sharpness : hint_range(1.0, 4000.0) = 300.0;
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.08;
uniform float ripple_speed : hint_range(0.0, 4.0) = 1.0;
uniform float lightning_flash : hint_range(0.0, 2.0) = 0.0;
uniform float lightning_reflection : hint_range(0.0, 1.0) = 0.3;

const int OCTAVES = 6;
const int RIPPLE_LAYERS = 3;
const float RIPPLE_WAVES[3] = float[](3.5, 1.4, 0.6);
const float RIPPLE_ANGLES[3] = float[](0.0, 1.2, -0.9);
const float RIPPLE_SPEEDS[3] = float[](2.6, 1.9, 1.3);
const float RIPPLE_STRETCH = 0.55;
const float RIPPLE_STEP = 0.05;
const float RIPPLE_PIXELS = 1.0;
const int WARPED_OCTAVES = 3;
const float OCTAVE_STEP = 0.55;
const float CHOP_WAVE = 6.0;
const float GUST_SIZE = 140.0;
const vec2 GUST_DRIFT = vec2(0.012, 0.02);
const float OCTAVE_SEED = 7.31;
const float WARP = 1.4;
const float CREST_STRETCH = 0.7;
const float SLOPE_STEP = 0.15;
const float FOAM_DRIFT = 0.15;
const float FOAM_LEVEL = 0.32;
const float GRAVITY = 9.81;
const float DISPLAY_GAMMA = 2.2;
const float DITHER_STEP = 1.0 / 255.0;
const float PIXELS_PER_WAVE = 1.0;
const float FOAM_FOOTPRINT = 2.0;

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(233.34, 851.73));
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
}

vec2 corner_slope(vec2 cell) {
	float angle = hash21(cell) * TAU;
	return vec2(cos(angle), sin(angle));
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

// Gradient noise: smoother than value noise and free of its grid creases.
float wave_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(corner_slope(i), f);
	float b = dot(corner_slope(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(corner_slope(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(corner_slope(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) + 0.5;
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

// Smooth gradient-like noise built from value noise, warped so crests
// never line up into the regular stripes a sum of sines gives.
float swell_noise(vec2 p) {
	vec2 warp = vec2(wave_noise(p * 0.5 + 3.1), wave_noise(p * 0.5 - 1.7)) - 0.5;
	return wave_noise(p + warp * WARP);
}

// Wave height in metres: octaves from long swell down to chop, each drifting
// downwind at its own deep-water speed, each dropped once it is below a pixel.
// Gusts roughen the water in drifting patches: rough patches catch more of
// the sky, calm slicks stay dark.
float gust(vec2 xz) {
	vec2 p = xz / GUST_SIZE + TIME * GUST_DRIFT;
	return mix(1.0 - gustiness, 1.0 + gustiness, value_noise(p) * 0.7 + value_noise(p * 2.3 + 4.7) * 0.3);
}

// Wave height in metres: octaves from swell down to chop, each drifting
// downwind at its own deep-water speed, each dropped once it is below a pixel.
float sea_height(vec2 xz, float footprint, float chop) {
	float wind = radians(wind_bearing_deg);
	vec2 downwind = vec2(sin(wind), -cos(wind));
	vec2 across = vec2(-downwind.y, downwind.x);
	vec2 local = vec2(dot(xz, across) * CREST_STRETCH, dot(xz, downwind));
	float sharp = steepness * (1.0 + roughness * storm_steepness);
	float height = 0.0;
	float wavelength = longest_wave;
	for (int i = 0; i < OCTAVES; i++) {
		float resolved = smoothstep(footprint * PIXELS_PER_WAVE, footprint * PIXELS_PER_WAVE * 2.0, wavelength);
		if (resolved <= 0.0) {
			break;
		}
		float speed = sqrt(GRAVITY * wavelength / TAU);
		vec2 p = (local - vec2(0.0, speed * TIME)) / wavelength + float(i) * OCTAVE_SEED;
		float shape = i < WARPED_OCTAVES ? swell_noise(p) : wave_noise(p);
		float boost = wavelength < CHOP_WAVE ? chop : 1.0;
		height += (shape - 0.5) * wavelength * sharp * boost * resolved;
		wavelength *= OCTAVE_STEP;
	}
	return height;
}

// Fast capillary ripples: three sheets crossing from different directions,
// sliding faster than the swell beneath them. These are what catch the moon.
vec2 ripple_slope(vec2 xz, float footprint) {
	float wind = radians(wind_bearing_deg);
	vec2 slope = vec2(0.0);
	for (int i = 0; i < RIPPLE_LAYERS; i++) {
		float wavelength = RIPPLE_WAVES[i];
		float resolved = smoothstep(footprint * RIPPLE_PIXELS, footprint * RIPPLE_PIXELS * 2.0, wavelength);
		if (resolved <= 0.0) {
			continue;
		}
		float angle = wind + RIPPLE_ANGLES[i];
		vec2 heading = vec2(sin(angle), -cos(angle));
		vec2 across = vec2(-heading.y, heading.x);
		vec2 p = vec2(dot(xz, across) * RIPPLE_STRETCH, dot(xz, heading) - RIPPLE_SPEEDS[i] * ripple_speed * TIME) / wavelength + float(i) * OCTAVE_SEED;
		float centre = wave_noise(p);
		float dx = wave_noise(p + vec2(RIPPLE_STEP, 0.0)) - centre;
		float dy = wave_noise(p + vec2(0.0, RIPPLE_STEP)) - centre;
		vec2 local = vec2(dx * RIPPLE_STRETCH, dy) / RIPPLE_STEP;
		slope += (across * local.x + heading * local.y) * ripple_strength * resolved;
	}
	return slope;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 view_ray = normalize(world_pos - CAMERA_POSITION_WORLD);
	float footprint = length(fwidth(world_pos.xz));
	float step_size = max(footprint, SLOPE_STEP);
	float chop = gust(world_pos.xz);
	float centre = sea_height(world_pos.xz, footprint, chop);
	float east = sea_height(world_pos.xz + vec2(step_size, 0.0), footprint, chop);
	float north = sea_height(world_pos.xz + vec2(0.0, step_size), footprint, chop);
	vec2 ripples = ripple_slope(world_pos.xz, footprint) * chop;
	vec3 normal = normalize(vec3((centre - east) / step_size - ripples.x, 1.0, (centre - north) / step_size - ripples.y));
	vec3 bounce = reflect(view_ray, normal);
	bounce.y = abs(bounce.y);

	float facing = clamp(dot(normal, -view_ray), 0.0, 1.0);
	float fresnel = reflectance + (1.0 - reflectance) * pow(1.0 - facing, 5.0);
	float v = mix(base_level, sky_level(bounce), fresnel);

	float toward_moon = max(dot(bounce, moon_direction()), 0.0);
	v += pow(toward_moon, moon_path_sharpness) * moon_path * fresnel;
	v += pow(toward_moon, glitter_sharpness) * glitter * fresnel;

	if (roughness > 0.0) {
		vec2 p = world_pos.xz * foam_scale;
		float lace = wave_noise(p + TIME * FOAM_DRIFT) * wave_noise(p * 2.7 - TIME * FOAM_DRIFT);
		float crest = smoothstep(0.0, 1.0, centre / (longest_wave * steepness * 0.25) + 0.5);
		float foam = smoothstep(foam_threshold, 1.0, lace * 2.0) * roughness * (0.4 + crest);
		v = mix(v, FOAM_LEVEL, foam * foam_level * smoothstep(FOAM_FOOTPRINT, FOAM_FOOTPRINT * 0.25, footprint));
	}

	v = max(v, 0.0) + lightning_flash * lightning_reflection;
	vec2 cell = FRAGCOORD.xy + fract(TIME) * 431.0;
	v += (hash21(cell) + hash21(cell + 17.0) - 1.0) * DITHER_STEP;
	ALBEDO = vec3(pow(max(v, 0.0), DISPLAY_GAMMA));
}
