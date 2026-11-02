shader_type canvas_item;
render_mode unshaded;

// Sensor stage: what the FLIR head itself produces, before the video chain.
// Optical softness, bloom on hot bodies and detail-peaking halos.

uniform float gain : hint_range(0.2, 4.0) = 1.35;
uniform float black_level : hint_range(0.0, 0.5) = 0.02;
uniform float levels : hint_range(2.0, 256.0) = 64.0;
uniform float sensor_floor : hint_range(0.0, 0.3) = 0.0;
uniform float optical_blur : hint_range(0.0, 1.0) = 0.55;
uniform float optical_blur_texels : hint_range(0.25, 2.0) = 0.7;
uniform float polarity : hint_range(0.0, 1.0) = 0.0;
uniform float bloom_amount : hint_range(0.0, 2.0) = 0.9;
uniform float bloom_floor : hint_range(0.0, 1.0) = 0.42;
uniform float bloom_radius_texels : hint_range(0.5, 4.0) = 1.4;
uniform float halo_amount : hint_range(0.0, 2.0) = 0.75;
uniform float halo_radius_texels : hint_range(1.0, 8.0) = 2.8;
uniform float shake_x = 0.0;
uniform float shake_y = 0.0;
uniform vec2 sensor_size = vec2(320.0, 180.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;

// Water on the lens: xy centre in UV, z radius (fraction of height), w strength.
const int MAX_DROPLETS = 12;
uniform vec4 droplets[MAX_DROPLETS];
uniform float droplet_refraction : hint_range(0.0, 3.0) = 1.6;
uniform float droplet_cooling : hint_range(0.0, 1.0) = 0.65;
uniform float droplet_rim : hint_range(0.0, 1.0) = 0.12;
uniform float chroma_keep : hint_range(0.0, 3.0) = 1.0;

// Detector flaws: uneven column gain, a few dead or stuck elements, lens falloff.
uniform float column_banding : hint_range(0.0, 0.1) = 0.018;
uniform float banding_drift_speed : hint_range(0.0, 1.0) = 0.05;
uniform float stuck_pixel_rate : hint_range(0.0, 0.01) = 0.0001;
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.22;

// Glints: the brightest points split into clean star rays with a faint spectral edge.
uniform float glint_threshold : hint_range(0.0, 1.0) = 0.7;
uniform float glint_strength : hint_range(0.0, 8.0) = 4.0;
uniform float glint_length_texels : hint_range(2.0, 64.0) = 34.0;
uniform float glint_rotation : hint_range(0.0, 3.1416) = 0.26;
uniform float glint_dispersion : hint_range(0.0, 0.5) = 0.18;
uniform float glint_shimmer_speed : hint_range(0.0, 10.0) = 2.5;

// Blast shockwaves: xy centre in UV, z ring radius (fraction of height), w strength.
const int MAX_RINGS = 4;
uniform vec4 shock_rings[MAX_RINGS];
uniform float shock_width : hint_range(0.005, 0.2) = 0.025;
uniform float shock_glow : hint_range(0.0, 20.0) = 4.0;

const vec3 LUMA = vec3(0.30, 0.59, 0.11);
const int RING_TAPS = 8;
const float COLUMN_SEED = 17.3;
const float STUCK_SEED = 91.7;
const float STUCK_BRIGHT_SHARE = 0.3;
const int GLINT_RAYS = 6;
const int GLINT_STEPS = 10;
const float GLINT_POINT_TEXELS = 3.0;
const float GLINT_HUE_CYCLES = 4.0;
const float GLINT_HUE_STRENGTH = 3.0;
const float GLINT_SHIMMER_PHASE = 2.1;
const float GLINT_FALLOFF = 2.2;
const float GLINT_SHIMMER_DEPTH = 0.35;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float column_gain(float column) {
	float drift = TIME * banding_drift_speed;
	float slow = mix(hash12(vec2(column, floor(drift))), hash12(vec2(column, floor(drift) + 1.0)), fract(drift));
	return 1.0 + (hash12(vec2(column, COLUMN_SEED)) + slow - 1.0) * column_banding;
}

float detector_flaws(float l, vec2 uv) {
	vec2 element = floor(uv * sensor_size);
	l *= column_gain(element.x);
	float stuck = hash12(element + STUCK_SEED);
	if (stuck < stuck_pixel_rate) {
		l = stuck < stuck_pixel_rate * STUCK_BRIGHT_SHARE ? 1.0 : 0.0;
	}
	vec2 from_centre = (uv - 0.5) * 2.0;
	return l * (1.0 - vignette_amount * dot(from_centre, from_centre) * 0.5);
}

vec2 ring_direction(int tap) {
	float angle = TAU * float(tap) / float(RING_TAPS);
	return vec2(cos(angle), sin(angle));
}

vec3 glint_spectrum(float along) {
	vec3 hue = clamp(abs(fract(along * glint_dispersion * GLINT_HUE_CYCLES + vec3(0.0, 0.333, 0.667)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return mix(vec3(1.0), hue, smoothstep(0.0, 1.0, along) * glint_dispersion * GLINT_HUE_STRENGTH);
}

float glint_point(float l, float side) {
	return max(l - max(side, glint_threshold), 0.0) / (1.0 - glint_threshold);
}

void fragment() {
	vec2 aspect = vec2(sensor_size.x / sensor_size.y, 1.0);
	vec2 bend = vec2(0.0);
	float wet = 0.0;
	float rim = 0.0;
	for (int i = 0; i < MAX_DROPLETS; i++) {
		vec4 drop = droplets[i];
		if (drop.w <= 0.0) {
			continue;
		}
		vec2 offset = (UV - drop.xy) * aspect / drop.z;
		float r2 = dot(offset, offset);
		if (r2 < 1.0) {
			float bulge = sqrt(1.0 - r2);
			bend -= (UV - drop.xy) * droplet_refraction * bulge * drop.w;
			wet = max(wet, bulge * drop.w);
			rim = max(rim, smoothstep(0.6, 0.95, r2) * (1.0 - r2) * 4.0 * drop.w);
		}
	}

	float shock_light = 0.0;
	for (int i = 0; i < MAX_RINGS; i++) {
		vec4 ring = shock_rings[i];
		if (ring.w <= 0.0) {
			continue;
		}
		vec2 offset = (UV - ring.xy) * aspect;
		float dist = length(offset);
		float band = (dist - ring.z) / shock_width;
		float front = exp(-band * band);
		bend -= offset / max(dist, 1e-4) / aspect * ring.w * front * band;
		shock_light += ring.w * front;
	}

	vec2 uv = clamp(UV + bend + vec2(shake_x, shake_y), vec2(0.0), vec2(1.0));
	vec2 texel = 1.0 / sensor_size;

	vec3 centre_colour = texture(TEXTURE, uv).rgb;
	float centre = dot(centre_colour, LUMA);
	float soft = 0.0;
	float near = 0.0;
	float far = 0.0;
	for (int i = 0; i < RING_TAPS; i++) {
		vec2 direction = ring_direction(i) * texel;
		soft += dot(texture(TEXTURE, uv + direction * optical_blur_texels).rgb, LUMA);
		near += dot(texture(TEXTURE, uv + direction * bloom_radius_texels).rgb, LUMA);
		far += dot(texture(TEXTURE, uv + direction * halo_radius_texels).rgb, LUMA);
	}
	soft /= float(RING_TAPS);
	near /= float(RING_TAPS);
	far /= float(RING_TAPS);

	float base = mix(centre, soft, mix(optical_blur, 1.0, wet));
	float l = base + max(near - bloom_floor, 0.0) * bloom_amount;
	l = max(l - black_level, 0.0) * gain;
	l = sensor_floor + l + (base - far) * halo_amount;

	l = l * (1.0 - droplet_cooling * wet) + droplet_rim * rim;
	l = clamp(detector_flaws(l + flash + shock_light * shock_glow, UV), 0.0, 1.0);

	l = floor(l * levels + 0.5) / levels;
	l = mix(l, 1.0 - l, polarity);

	vec3 chroma = (centre_colour - vec3(centre)) * chroma_keep;
	vec3 glint = vec3(0.0);
	for (int ray = 0; ray < GLINT_RAYS; ray++) {
		float angle = glint_rotation + TAU * float(ray) / float(GLINT_RAYS);
		vec2 heading = vec2(cos(angle), sin(angle));
		vec2 direction = heading * texel * glint_length_texels;
		vec2 across = vec2(-heading.y, heading.x) * texel * GLINT_POINT_TEXELS;
		float shimmer = 1.0 - GLINT_SHIMMER_DEPTH * (0.5 + 0.5 * sin(TIME * glint_shimmer_speed + float(ray) * GLINT_SHIMMER_PHASE));
		for (int step = 1; step <= GLINT_STEPS; step++) {
			float along = float(step) / float(GLINT_STEPS);
			vec2 at = uv - direction * along;
			float point = glint_point(
				dot(texture(TEXTURE, at).rgb, LUMA),
				max(dot(texture(TEXTURE, at + across).rgb, LUMA), dot(texture(TEXTURE, at - across).rgb, LUMA))
			);
			glint += point * exp(-along * GLINT_FALLOFF) * shimmer * glint_spectrum(along);
		}
	}
	glint *= glint_strength / float(GLINT_STEPS);

	COLOR = vec4(clamp(vec3(l) + chroma + glint, 0.0, 1.0), 1.0);
}
