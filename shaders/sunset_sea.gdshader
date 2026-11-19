shader_type spatial;
render_mode unshaded, shadows_disabled;

#include "res://shaders/sunset.gdshaderinc"

// Dark swell under a low sun: each wave face mirrors the sunset sky, and a
// broken path of glitter runs from the sun toward us.

uniform float sun_elevation_deg = 3.0;
uniform float sun_bearing_deg = 270.0;
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
uniform vec3 deep_water : source_color = vec3(0.006, 0.006, 0.012);
uniform float wave_scale = 0.16;
uniform float wave_tilt = 0.12;
uniform float glitter_sharpness = 900.0;
uniform float glitter_strength = 14.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 slope(vec2 p) {
	vec2 s = vec2(0.0);
	float amplitude = 1.0;
	float frequency = 1.0;
	for (int octave = 0; octave < 5; octave++) {
		float angle = float(octave) * 2.39;
		vec2 heading = vec2(cos(angle), sin(angle));
		float phase = dot(p, heading) * frequency + TIME * (0.8 + 0.35 * float(octave));
		s += heading * cos(phase) * amplitude;
		frequency *= 1.9;
		amplitude *= 0.62;
	}
	s += (vec2(sunset_noise(p * 6.0 + TIME), sunset_noise(p * 6.0 - TIME + 7.0)) - 0.5) * 0.6;
	return s;
}

void fragment() {
	vec3 sun = sunset_sun_direction(sun_elevation_deg, sun_bearing_deg);
	vec3 eye = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 view = normalize(world_position - eye);
	vec2 tilt = slope(world_position.xz * wave_scale) * wave_tilt;
	vec3 normal = normalize(vec3(-tilt.x, 1.0, -tilt.y));
	vec3 mirrored = reflect(view, normal);
	mirrored.y = abs(mirrored.y);
	float fresnel = 0.04 + 0.96 * pow(1.0 - max(dot(-view, normal), 0.0), 5.0);
	vec3 sky = sunset_sky(mirrored, sun, daylight, TIME);
	float glint = pow(max(dot(mirrored, sun), 0.0), glitter_sharpness) * glitter_strength * daylight;
	ALBEDO = mix(deep_water, sky, fresnel) + vec3(1.0, 0.62, 0.3) * glint;
}
