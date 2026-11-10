shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// Night sea: a dark water body mirroring the sky glow, with moon glints.

uniform float base_level : hint_range(0.0, 0.5) = 0.03;
uniform float sky_horizon_level : hint_range(0.0, 1.0) = 0.16;
uniform float sky_top_level : hint_range(0.0, 1.0) = 0.09;
uniform float sky_curve : hint_range(0.001, 1.0) = 0.12;
uniform float reflectance : hint_range(0.0, 0.2) = 0.06;
uniform float wind_bearing_deg : hint_range(0.0, 360.0) = 60.0;
uniform sampler2D sparkle_normals : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float wave_steepness : hint_range(0.0, 1.0) = 0.14;
uniform float wave_evolve : hint_range(0.0, 4.0) = 0.6;
uniform float glint_ripple : hint_range(0.0, 3.0) = 0.8;
uniform float gustiness : hint_range(0.0, 1.0) = 0.55;
uniform float roughness : hint_range(0.0, 1.0) = 0.0;
uniform float storm_steepness : hint_range(0.0, 2.0) = 1.4;
uniform float foam_level : hint_range(0.0, 1.0) = 0.45;
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.45;
uniform float foam_scale = 0.12;
uniform float moon_bearing_deg : hint_range(0.0, 360.0) = 140.0;
uniform float moon_elevation_deg : hint_range(0.0, 90.0) = 22.0;
uniform float moon_path : hint_range(0.0, 2.0) = 0.25;
uniform float moon_path_sharpness : hint_range(1.0, 2000.0) = 25.0;
uniform float glitter : hint_range(0.0, 12.0) = 7.0;
uniform float glitter_sharpness : hint_range(1.0, 12000.0) = 4500.0;
uniform float ripple_speed : hint_range(0.0, 4.0) = 1.0;
uniform float rain : hint_range(0.0, 1.0) = 0.0;
uniform float rain_ripple_strength : hint_range(0.0, 2.0) = 0.6;
uniform float lightning_flash : hint_range(0.0, 2.0) = 0.0;
uniform float lightning_reflection : hint_range(0.0, 1.0) = 0.3;

const int WAVE_OCTAVES = 4;
const float WAVE_LENGTHS[4] = float[](12.0, 5.5, 2.5, 1.2);
const float WAVE_WEIGHTS[4] = float[](1.0, 0.8, 0.6, 0.45);
const float WAVE_SEED = 17.3;
const float WAVE_PIXELS = 2.0;
const float GRAVITY = 9.81;
const int GLINT_LAYERS = 3;
const float GLINT_TILES[3] = float[](7.0, 3.0, 1.6);
const float GLINT_STRETCH = 1.0;
const float GLINT_ANGLES[3] = float[](0.4, 1.0, -2.1);
const float GLINT_SPEED = 0.8;
const float GUST_SIZE = 140.0;
const vec2 GUST_DRIFT = vec2(0.012, 0.02);
const float FOAM_DRIFT = 0.15;
const float GLINT_FLOOR = 0.5;
const float RAIN_CELL = 2.5;
const float RAIN_RATE = 1.3;
const float RAIN_REACH = 0.45;
const float RAIN_WAVES = 60.0;
const float RAIN_SHARPNESS = 400.0;
const float RAIN_SEED = 13.7;
const float FOAM_LEVEL = 0.32;
const float DISPLAY_GAMMA = 2.2;
const float DITHER_STEP = 1.0 / 255.0;
const float DITHER_SEED = 431.0;
const float DITHER_OFFSET = 17.0;
const float MIN_NORMAL_Z = 0.2;
const float RAIN_MARGIN = 0.2;
const float RAIN_PIXELS = 3.0;
const float FINE_RAIN_SCALE = 0.6;
const float GUST_DETAIL = 2.3;
const vec2 GUST_SEED = vec2(4.7);
const float GUST_DETAIL_SHARE = 0.3;
const float FRESNEL_POWER = 5.0;
const float FOAM_DETAIL = 2.7;
const float FOAM_GAIN = 2.0;
const float FOAM_SHARP_SHARE = 0.25;
const float FOAM_FOOTPRINT = 2.0;

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(233.34, 851.73));
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
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

vec3 corner_gradient(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453) * 2.0 - 1.0;
}

// 3D gradient noise with its derivatives (x: value, yzw: gradient).
vec4 gradient_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	vec3 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);
	vec3 ga = corner_gradient(i);
	vec3 gb = corner_gradient(i + vec3(1.0, 0.0, 0.0));
	vec3 gc = corner_gradient(i + vec3(0.0, 1.0, 0.0));
	vec3 gd = corner_gradient(i + vec3(1.0, 1.0, 0.0));
	vec3 ge = corner_gradient(i + vec3(0.0, 0.0, 1.0));
	vec3 gf = corner_gradient(i + vec3(1.0, 0.0, 1.0));
	vec3 gg = corner_gradient(i + vec3(0.0, 1.0, 1.0));
	vec3 gh = corner_gradient(i + vec3(1.0, 1.0, 1.0));
	float va = dot(ga, f);
	float vb = dot(gb, f - vec3(1.0, 0.0, 0.0));
	float vc = dot(gc, f - vec3(0.0, 1.0, 0.0));
	float vd = dot(gd, f - vec3(1.0, 1.0, 0.0));
	float ve = dot(ge, f - vec3(0.0, 0.0, 1.0));
	float vf = dot(gf, f - vec3(1.0, 0.0, 1.0));
	float vg = dot(gg, f - vec3(0.0, 1.0, 1.0));
	float vh = dot(gh, f - vec3(1.0, 1.0, 1.0));
	float value = va + u.x * (vb - va) + u.y * (vc - va) + u.z * (ve - va)
		+ u.x * u.y * (va - vb - vc + vd) + u.y * u.z * (va - vc - ve + vg)
		+ u.z * u.x * (va - vb - ve + vf) + (-va + vb + vc - vd + ve - vf - vg + vh) * u.x * u.y * u.z;
	vec3 gradient = ga + u.x * (gb - ga) + u.y * (gc - ga) + u.z * (ge - ga)
		+ u.x * u.y * (ga - gb - gc + gd) + u.y * u.z * (ga - gc - ge + gg)
		+ u.z * u.x * (ga - gb - ge + gf) + (-ga + gb + gc - gd + ge - gf - gg + gh) * u.x * u.y * u.z
		+ du * (vec3(vb, vc, ve) - va
			+ u.yzx * vec3(va - vb - vc + vd, va - vc - ve + vg, va - vb - ve + vf)
			+ u.zxy * vec3(va - vb - ve + vf, va - vb - vc + vd, va - vc - ve + vg)
			+ u.yzx * u.zxy * (-va + vb + vc - vd + ve - vf - vg + vh));
	return vec4(value, gradient);
}

// Calm open water: round wavelets at a few sizes that swell and fade where they
// are, without travelling, the way still water moves under light wind.
vec2 water_slope(vec2 xz, float footprint, float strength) {
	vec2 slope = vec2(0.0);
	for (int i = 0; i < WAVE_OCTAVES; i++) {
		float wavelength = WAVE_LENGTHS[i];
		float resolved = smoothstep(footprint * WAVE_PIXELS, footprint * WAVE_PIXELS * 2.0, wavelength);
		if (resolved <= 0.0) {
			break;
		}
		float rate = sqrt(GRAVITY * TAU / wavelength) / TAU * wave_evolve;
		vec4 n = gradient_noise(vec3(xz / wavelength, TIME * rate + float(i) * WAVE_SEED));
		slope += n.yz * WAVE_WEIGHTS[i] * resolved;
	}
	return slope * strength;
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

vec2 sparkle_layer(vec2 xz, float angle, float tile, float speed, float stretch, float strength) {
	vec2 heading = vec2(sin(angle), -cos(angle));
	vec2 across = vec2(-heading.y, heading.x);
	vec2 uv = vec2(dot(xz, across) * stretch, dot(xz, heading) - speed * TIME) / tile;
	vec3 n = texture(sparkle_normals, uv).xyz * 2.0 - 1.0;
	vec2 local = n.xy / max(n.z, MIN_NORMAL_Z) * vec2(stretch, 1.0);
	return (across * local.x + heading * local.y) * strength;
}

vec2 rain_rings(vec2 xz, float cell_size, float footprint) {
	vec2 cell = floor(xz / cell_size);
	vec2 within = fract(xz / cell_size);
	float seed = hash21(cell);
	vec2 centre = vec2(hash21(cell + RAIN_SEED), hash21(cell - RAIN_SEED)) * (1.0 - 2.0 * RAIN_MARGIN) + RAIN_MARGIN;
	float age = fract(TIME * RAIN_RATE + seed);
	vec2 offset = within - centre;
	float distance = length(offset);
	float front = distance - age * RAIN_REACH;
	float ring = sin(front * RAIN_WAVES) * exp(-front * front * RAIN_SHARPNESS) * (1.0 - age);
	float visible = smoothstep(footprint * RAIN_PIXELS, footprint * RAIN_PIXELS * 2.0, cell_size);
	return offset / max(distance, 1e-3) * ring * visible;
}

float gust(vec2 xz) {
	vec2 p = xz / GUST_SIZE + TIME * GUST_DRIFT;
	return mix(1.0 - gustiness, 1.0 + gustiness, mix(value_noise(p), value_noise(p * GUST_DETAIL + GUST_SEED), GUST_DETAIL_SHARE));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 view_ray = normalize(world_pos - CAMERA_POSITION_WORLD);
	float wind = radians(wind_bearing_deg);
	float sea = 1.0 + roughness * storm_steepness;
	float chop = gust(world_pos.xz) * sea;
	float footprint = length(fwidth(world_pos.xz));
	vec2 slope = water_slope(world_pos.xz, footprint, wave_steepness * chop);
	vec2 water = slope;
	if (rain > 0.0) {
		slope += (rain_rings(world_pos.xz, RAIN_CELL, footprint) + rain_rings(world_pos.xz + RAIN_SEED, RAIN_CELL * FINE_RAIN_SCALE, footprint)) * rain * rain_ripple_strength;
	}
	vec3 normal = normalize(vec3(-slope.x, 1.0, -slope.y));
	// Glints ride the water plus their own fine sparkle ripples.
	vec2 sparkle = water;
	for (int i = 0; i < GLINT_LAYERS; i++) {
		sparkle += sparkle_layer( world_pos.xz, wind + GLINT_ANGLES[i], GLINT_TILES[i], GLINT_SPEED * ripple_speed, GLINT_STRETCH, glint_ripple * chop);
	}
	vec3 glint_bounce = reflect(view_ray, normalize(vec3(-sparkle.x, 1.0, -sparkle.y)));
	vec3 bounce = reflect(view_ray, normal);
	bounce.y = abs(bounce.y);

	float facing = clamp(dot(normal, -view_ray), 0.0, 1.0);
	float fresnel = reflectance + (1.0 - reflectance) * pow(1.0 - facing, FRESNEL_POWER);
	float v = mix(base_level, sky_level(bounce), fresnel);

	float toward_moon = max(dot(bounce, moon_direction()), 0.0);
	v += pow(toward_moon, moon_path_sharpness) * moon_path * fresnel;
	v += pow(max(dot(glint_bounce, moon_direction()), 0.0), glitter_sharpness) * glitter * (GLINT_FLOOR + fresnel);

	if (roughness > 0.0) {
		vec2 p = world_pos.xz * foam_scale;
		float lace = value_noise(p + TIME * FOAM_DRIFT) * value_noise(p * FOAM_DETAIL - TIME * FOAM_DRIFT);
		float foam = smoothstep(foam_threshold, 1.0, lace * FOAM_GAIN) * roughness;
		v = mix(v, FOAM_LEVEL, foam * foam_level * smoothstep(FOAM_FOOTPRINT, FOAM_FOOTPRINT * FOAM_SHARP_SHARE, footprint));
	}

	v = max(v, 0.0) + lightning_flash * lightning_reflection;
	vec2 cell = FRAGCOORD.xy + fract(TIME) * DITHER_SEED;
	v += (hash21(cell) + hash21(cell + DITHER_OFFSET) - 1.0) * DITHER_STEP;
	ALBEDO = vec3(pow(max(v, 0.0), DISPLAY_GAMMA));
}
