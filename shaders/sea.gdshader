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
uniform sampler2D wave_normals : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float swell_strength : hint_range(0.0, 2.0) = 0.4;
uniform float ripple_strength : hint_range(0.0, 2.0) = 0.5;
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
uniform float glitter : hint_range(0.0, 4.0) = 1.6;
uniform float glitter_sharpness : hint_range(1.0, 4000.0) = 300.0;
uniform float ripple_speed : hint_range(0.0, 4.0) = 1.0;
uniform float rain : hint_range(0.0, 1.0) = 0.0;
uniform float rain_ripple_strength : hint_range(0.0, 2.0) = 0.6;
uniform float lightning_flash : hint_range(0.0, 2.0) = 0.0;
uniform float lightning_reflection : hint_range(0.0, 1.0) = 0.3;

const int RIPPLE_LAYERS = 3;
const float RIPPLE_TILES[3] = float[](14.0, 6.0, 2.5);
const float RIPPLE_ANGLES[3] = float[](0.0, 0.65, -0.55);
const float RIPPLE_SPEEDS[3] = float[](3.2, 2.4, 1.6);
const float RIPPLE_STRETCH = 0.45;
const float SWELL_TILE = 90.0;
const float SWELL_ANGLE = 0.3;
const float SWELL_SPEED = 4.0;
const float GUST_SIZE = 140.0;
const vec2 GUST_DRIFT = vec2(0.012, 0.02);
const float FOAM_DRIFT = 0.15;
const float RAIN_CELL = 2.5;
const float RAIN_RATE = 1.3;
const float RAIN_REACH = 0.45;
const float RAIN_WAVES = 60.0;
const float RAIN_SHARPNESS = 400.0;
const float RAIN_SEED = 13.7;
const float FOAM_LEVEL = 0.32;
const float DISPLAY_GAMMA = 2.2;
const float DITHER_STEP = 1.0 / 255.0;
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

// One tileable wave normal map, sampled as a slow swell plus three ripple
// sheets crossing from different directions. Mipmaps keep it clean all the
// way to the horizon, and five texture reads cost almost nothing.
vec2 wave_layer(vec2 xz, float angle, float tile, float speed, float stretch, float strength) {
	vec2 heading = vec2(sin(angle), -cos(angle));
	vec2 across = vec2(-heading.y, heading.x);
	vec2 uv = vec2(dot(xz, across) * stretch, dot(xz, heading) - speed * TIME) / tile;
	vec3 n = texture(wave_normals, uv).xyz * 2.0 - 1.0;
	vec2 local = n.xy / max(n.z, 0.2) * vec2(stretch, 1.0);
	return (across * local.x + heading * local.y) * strength;
}

// Raindrop rings: every cell gets a drop at its own moment, and the ring
// spreads out and fades before the next one lands there.
vec2 rain_rings(vec2 xz, float cell_size, float footprint) {
	vec2 cell = floor(xz / cell_size);
	vec2 within = fract(xz / cell_size);
	float seed = hash21(cell);
	vec2 centre = vec2(hash21(cell + RAIN_SEED), hash21(cell - RAIN_SEED)) * 0.6 + 0.2;
	float age = fract(TIME * RAIN_RATE + seed);
	vec2 offset = within - centre;
	float distance = length(offset);
	float front = distance - age * RAIN_REACH;
	float ring = sin(front * RAIN_WAVES) * exp(-front * front * RAIN_SHARPNESS) * (1.0 - age);
	float visible = smoothstep(footprint * 3.0, footprint * 6.0, cell_size);
	return offset / max(distance, 1e-3) * ring * visible;
}

// Gusts roughen the water in drifting patches: rough patches catch more of
// the sky, calm slicks stay dark.
float gust(vec2 xz) {
	vec2 p = xz / GUST_SIZE + TIME * GUST_DRIFT;
	return mix(1.0 - gustiness, 1.0 + gustiness, value_noise(p) * 0.7 + value_noise(p * 2.3 + 4.7) * 0.3);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 view_ray = normalize(world_pos - CAMERA_POSITION_WORLD);
	float wind = radians(wind_bearing_deg);
	float sea = 1.0 + roughness * storm_steepness;
	float chop = gust(world_pos.xz) * sea;
	vec2 slope = wave_layer(world_pos.xz, wind + SWELL_ANGLE, SWELL_TILE, SWELL_SPEED, 1.0, swell_strength * sea);
	for (int i = 0; i < RIPPLE_LAYERS; i++) {
		slope += wave_layer(world_pos.xz, wind + RIPPLE_ANGLES[i], RIPPLE_TILES[i], RIPPLE_SPEEDS[i] * ripple_speed, RIPPLE_STRETCH, ripple_strength * chop);
	}
	if (rain > 0.0) {
		float footprint = length(fwidth(world_pos.xz));
		slope += (rain_rings(world_pos.xz, RAIN_CELL, footprint) + rain_rings(world_pos.xz + RAIN_SEED, RAIN_CELL * 0.6, footprint)) * rain * rain_ripple_strength;
	}
	vec3 normal = normalize(vec3(-slope.x, 1.0, -slope.y));
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
		float lace = value_noise(p + TIME * FOAM_DRIFT) * value_noise(p * 2.7 - TIME * FOAM_DRIFT);
		float foam = smoothstep(foam_threshold, 1.0, lace * 2.0) * roughness;
		float footprint = length(fwidth(world_pos.xz));
		v = mix(v, FOAM_LEVEL, foam * foam_level * smoothstep(FOAM_FOOTPRINT, FOAM_FOOTPRINT * 0.25, footprint));
	}

	v = max(v, 0.0) + lightning_flash * lightning_reflection;
	vec2 cell = FRAGCOORD.xy + fract(TIME) * 431.0;
	v += (hash21(cell) + hash21(cell + 17.0) - 1.0) * DITHER_STEP;
	ALBEDO = vec3(pow(max(v, 0.0), DISPLAY_GAMMA));
}
