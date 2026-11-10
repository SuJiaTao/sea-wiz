shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// Night sea: a dark water body mirroring the sky glow, with moon glints.

uniform float base_level : hint_range(0.0, 0.5) = 0.03;
uniform float sky_horizon_level : hint_range(0.0, 1.0) = 0.16;
uniform float sky_top_level : hint_range(0.0, 1.0) = 0.09;
uniform float sky_curve : hint_range(0.001, 1.0) = 0.12;
uniform float reflectance : hint_range(0.0, 0.2) = 0.06;
uniform float wind_bearing_deg : hint_range(0.0, 360.0) = 60.0;
uniform sampler2D wave_normals : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float swell_strength : hint_range(0.0, 2.0) = 0.25;
uniform float ripple_strength : hint_range(0.0, 2.0) = 0.55;
uniform float glint_ripple : hint_range(0.0, 2.0) = 0.9;
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
uniform float glitter : hint_range(0.0, 12.0) = 4.0;
uniform float sheen : hint_range(0.0, 8.0) = 1.4;
uniform float sheen_sharpness : hint_range(1.0, 2000.0) = 120.0;
uniform float crinkle_sharpness : hint_range(1.0, 4000.0) = 250.0;
uniform float glitter_sharpness : hint_range(1.0, 8000.0) = 3000.0;
uniform float ripple_speed : hint_range(0.0, 4.0) = 1.0;
uniform float rain : hint_range(0.0, 1.0) = 0.0;
uniform float rain_ripple_strength : hint_range(0.0, 2.0) = 0.6;
uniform float lightning_flash : hint_range(0.0, 2.0) = 0.0;
uniform float lightning_reflection : hint_range(0.0, 1.0) = 0.3;

const int RIPPLE_LAYERS = 3;
const float RIPPLE_TILES[3] = float[](26.0, 17.0, 11.0);
const float RIPPLE_ANGLES[3] = float[](0.0, 2.094, -2.094);
const float RIPPLE_SPEEDS[3] = float[](0.7, 0.7, 0.7);
const float RIPPLE_STRETCH = 0.3;
const int GLINT_LAYERS = 2;
const float GLINT_TILES[2] = float[](1.9, 1.1);
const float GLINT_ANGLES[2] = float[](1.0, -2.1);
const float GLINT_SPEED = 0.8;
const float SWELL_TILE = 90.0;
const float SWELL_ANGLE = 0.3;
const float SWELL_SPEED = 1.5;
const vec2 SWELL_OFFSET = vec2(37.0, 11.0);
const float GUST_SIZE = 140.0;
const vec2 GUST_DRIFT = vec2(0.012, 0.02);
const float FOAM_DRIFT = 0.15;
const float GLINT_FLOOR = 0.5;
const float CRINKLE_FLOOR = 0.04;
const float CRINKLE_STRETCH = 0.8;
const float GLINT_SPREAD = 6.0;
const float GLINT_SPREAD_MAX = 2.5;
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
const float SWELL_SHARE = 0.7;
const float COUNTER_SWELL_SCALE = 0.8;
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

vec3 moon_direction() {
	float bearing = radians(moon_bearing_deg);
	float elevation = radians(moon_elevation_deg);
	return vec3(sin(bearing) * cos(elevation), sin(elevation), -cos(bearing) * cos(elevation));
}

float sky_level(vec3 ray) {
	float c = 1.0 - acos(clamp(abs(ray.y), 0.0, 1.0)) / (PI * 0.5);
	return mix(sky_horizon_level, sky_top_level, clamp(1.0 - pow(1.0 - c, 1.0 / sky_curve), 0.0, 1.0));
}

vec2 wave_layer(vec2 xz, float angle, float tile, float speed, float stretch, float strength) {
	vec2 heading = vec2(sin(angle), -cos(angle));
	vec2 across = vec2(-heading.y, heading.x);
	vec2 uv = vec2(dot(xz, across) * stretch, dot(xz, heading) - speed * TIME) / tile;
	vec3 n = texture(wave_normals, uv).xyz * 2.0 - 1.0;
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
	// Two swells meeting head on: the sea heaves in place instead of flowing.
	vec2 slope = wave_layer(world_pos.xz, wind + SWELL_ANGLE, SWELL_TILE, SWELL_SPEED, 1.0, swell_strength * sea * SWELL_SHARE)
		+ wave_layer(world_pos.xz + SWELL_OFFSET, wind + SWELL_ANGLE + PI, SWELL_TILE * COUNTER_SWELL_SCALE, SWELL_SPEED, 1.0, swell_strength * sea * SWELL_SHARE);
	for (int i = 0; i < RIPPLE_LAYERS; i++) {
		slope += wave_layer(world_pos.xz, wind + RIPPLE_ANGLES[i], RIPPLE_TILES[i], RIPPLE_SPEEDS[i] * ripple_speed, RIPPLE_STRETCH, ripple_strength * chop);
	}
	if (rain > 0.0) {
		float footprint = length(fwidth(world_pos.xz));
		slope += (rain_rings(world_pos.xz, RAIN_CELL, footprint) + rain_rings(world_pos.xz + RAIN_SEED, RAIN_CELL * FINE_RAIN_SCALE, footprint)) * rain * rain_ripple_strength;
	}
	vec3 normal = normalize(vec3(-slope.x, 1.0, -slope.y));
	// Fine sparkle ripples only tilt the glints; the body of the water stays glassy.
	vec2 sparkle = slope;
	for (int i = 0; i < GLINT_LAYERS; i++) {
		sparkle += wave_layer(world_pos.xz, wind + GLINT_ANGLES[i], GLINT_TILES[i], GLINT_SPEED * ripple_speed, CRINKLE_STRETCH, glint_ripple * chop);
	}
	vec3 glint_bounce = reflect(view_ray, normalize(vec3(-sparkle.x, 1.0, -sparkle.y)));
	vec3 bounce = reflect(view_ray, normal);
	bounce.y = abs(bounce.y);

	float facing = clamp(dot(normal, -view_ray), 0.0, 1.0);
	float fresnel = reflectance + (1.0 - reflectance) * pow(1.0 - facing, FRESNEL_POWER);
	float v = mix(base_level, sky_level(bounce), fresnel);

	float toward_moon = max(dot(bounce, moon_direction()), 0.0);
	v += pow(toward_moon, moon_path_sharpness) * moon_path * fresnel;
	// Swell faces turned to the moon light up as patches, crinkled by the fine ripples.
	float sheen_face = pow(toward_moon, sheen_sharpness);
	float crinkle = pow(max(dot(glint_bounce, moon_direction()), 0.0), crinkle_sharpness);
	v += sheen_face * (CRINKLE_FLOOR + crinkle) * sheen * fresnel;
	// Sub-pixel sparkle ripples: widen the glint lobe so the moon path still twinkles far out.
	float glint_footprint = length(fwidth(world_pos.xz));
	float spread = min(1.0 + glint_footprint * GLINT_SPREAD, GLINT_SPREAD_MAX);
	v += pow(max(dot(glint_bounce, moon_direction()), 0.0), glitter_sharpness / spread) * glitter * (GLINT_FLOOR + fresnel) / sqrt(spread);

	if (roughness > 0.0) {
		vec2 p = world_pos.xz * foam_scale;
		float lace = value_noise(p + TIME * FOAM_DRIFT) * value_noise(p * FOAM_DETAIL - TIME * FOAM_DRIFT);
		float foam = smoothstep(foam_threshold, 1.0, lace * FOAM_GAIN) * roughness;
		float footprint = length(fwidth(world_pos.xz));
		v = mix(v, FOAM_LEVEL, foam * foam_level * smoothstep(FOAM_FOOTPRINT, FOAM_FOOTPRINT * FOAM_SHARP_SHARE, footprint));
	}

	v = max(v, 0.0) + lightning_flash * lightning_reflection;
	vec2 cell = FRAGCOORD.xy + fract(TIME) * DITHER_SEED;
	v += (hash21(cell) + hash21(cell + DITHER_OFFSET) - 1.0) * DITHER_STEP;
	ALBEDO = vec3(pow(max(v, 0.0), DISPLAY_GAMMA));
}
