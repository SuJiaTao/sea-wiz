shader_type spatial;
render_mode unshaded, shadows_disabled;

#include "res://shaders/sunset.gdshaderinc"

// Dark swell under a low sun: each wave face mirrors the sunset sky, and a
// broken path of glitter runs from the sun toward us until it slips under. Far off, ripples too
// fine to see are smoothed away and the glitter softens, so nothing shimmers.

uniform float sun_elevation_deg = 3.0;
uniform float sun_bearing_deg = 270.0;
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
uniform vec3 deep_water : source_color = vec3(0.006, 0.006, 0.012);
uniform float wave_scale = 0.1;
uniform float wave_tilt = 0.085;
uniform float glitter_sharpness = 900.0;
uniform float glitter_strength = 5.0;

const float GLINT_SOFTENING = 12.0;
const vec3 GLINT_COLOUR = vec3(1.0, 0.5, 0.15);
// The glitter path dies as the last of the disc slips under.
const float SUN_RADIUS_DEG = 0.6;
// Even at a grazing angle the sea stays a little darker than the sky, so the
// horizon line holds and the sun visibly sinks into it.
const float HORIZON_REFLECTION = 0.62;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Ripples finer than a pixel are faded out rather than left to shimmer.
float resolved(float footprint, float frequency) {
	return 1.0 - smoothstep(0.25, 0.9, footprint * frequency);
}

vec2 slope(vec2 p, float footprint) {
	vec2 s = vec2(0.0);
	float amplitude = 1.0;
	float frequency = 1.0;
	for (int octave = 0; octave < 7; octave++) {
		float angle = float(octave) * 2.39;
		vec2 heading = vec2(cos(angle), sin(angle));
		float phase = dot(p, heading) * frequency + TIME * (0.8 + 0.35 * float(octave));
		s += heading * cos(phase) * amplitude * resolved(footprint, frequency);
		frequency *= 1.85;
		amplitude *= 0.58;
	}
	vec2 fine = vec2(sunset_noise(p * 6.0 + TIME), sunset_noise(p * 6.0 - TIME + 7.0)) - 0.5;
	s += fine * 0.4 * resolved(footprint, 6.0);
	return s;
}

void fragment() {
	vec3 sun = sunset_sun_direction(sun_elevation_deg, sun_bearing_deg);
	vec3 eye = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 view = normalize(world_position - eye);
	vec2 p = world_position.xz * wave_scale;
	float footprint = length(fwidth(p));
	vec2 tilt = slope(p, footprint) * wave_tilt;
	vec3 normal = normalize(vec3(-tilt.x, 1.0, -tilt.y));
	vec3 mirrored = reflect(view, normal);
	mirrored.y = abs(mirrored.y);
	float fresnel = 0.04 + HORIZON_REFLECTION * pow(1.0 - max(dot(-view, normal), 0.0), 5.0);
	vec3 sky = sunset_sky(mirrored, sun, daylight, TIME, false);
	float sharpness = glitter_sharpness / (1.0 + footprint * GLINT_SOFTENING);
	float above = smoothstep(-SUN_RADIUS_DEG, SUN_RADIUS_DEG, sunset_elevation(sun));
	float glint = pow(max(dot(mirrored, sun), 0.0), sharpness) * glitter_strength * above * daylight * sharpness / glitter_sharpness;
	ALBEDO = mix(deep_water, sky, fresnel) + GLINT_COLOUR * glint;
}
