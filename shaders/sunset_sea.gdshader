shader_type spatial;
render_mode unshaded, shadows_disabled;

#include "res://shaders/sunset.gdshaderinc"

// Dark swell at dusk: each wave face mirrors the sunset sky. Ripples too
// small to see at a distance are smoothed away so the far sea does not
// break up into shimmering pixels.

uniform float sun_elevation_deg = 3.0;
uniform float sun_bearing_deg = 270.0;
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
uniform vec3 deep_water : source_color = vec3(0.006, 0.006, 0.012);
uniform float wave_scale = 0.25;
uniform float wave_tilt = 0.09;

const float RIPPLE_STRETCH = 4.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Height of the small chop: long ripples lying across the line of sight, so
// the bright sky reflects as broken horizontal streaks.
float chop(vec2 p, float footprint) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 5; octave++) {
		float visible = 1.0 - smoothstep(0.1, 0.5, footprint);
		total += (sunset_noise(p) - 0.5) * amplitude * visible;
		p = p * 2.03 + vec2(1.7, 9.2);
		footprint *= 2.03;
		amplitude *= 0.55;
	}
	return total;
}

vec2 slope(vec2 p, float footprint) {
	const float STEP = 0.05;
	vec2 drift = vec2(TIME * 0.35, TIME * 0.12);
	float here = chop(p + drift, footprint);
	float across = chop(p + drift + vec2(STEP, 0.0), footprint);
	float along = chop(p + drift + vec2(0.0, STEP), footprint);
	return vec2(across - here, along - here) / STEP;
}

void fragment() {
	vec3 sun = sunset_sun_direction(sun_elevation_deg, sun_bearing_deg);
	vec3 eye = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 view = normalize(world_position - eye);
	vec2 p = vec2(world_position.z, world_position.x * RIPPLE_STRETCH) * wave_scale;
	float footprint = length(fwidth(p));
	vec2 tilt = slope(p, footprint) * wave_tilt;
	vec3 normal = normalize(vec3(-tilt.y * RIPPLE_STRETCH, 1.0, -tilt.x));
	vec3 mirrored = reflect(view, normal);
	mirrored.y = abs(mirrored.y);
	float fresnel = 0.04 + 0.96 * pow(1.0 - max(dot(-view, normal), 0.0), 5.0);
	vec3 sky = sunset_sky(mirrored, sun, daylight, TIME);
	ALBEDO = mix(deep_water, sky, fresnel);
}
