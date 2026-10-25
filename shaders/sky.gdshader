shader_type sky;

// Thermal sky: cold overhead, warmer toward the horizon where the sensor looks
// through more air, and the moon. The moon's sunlit side is hot rock and shows
// bright; its night side is colder than the sky behind it.

uniform vec3 sky_top_color : source_color = vec3(0.0);
uniform vec3 sky_horizon_color : source_color = vec3(0.16);
uniform float sky_curve : hint_range(0.001, 1.0) = 0.06;
uniform vec3 ground_horizon_color : source_color = vec3(0.16);
uniform vec3 ground_bottom_color : source_color = vec3(0.0);
uniform float ground_curve : hint_range(0.001, 1.0) = 0.02;

uniform float moon_bearing_deg : hint_range(0.0, 360.0) = 140.0;
uniform float moon_elevation_deg : hint_range(0.0, 90.0) = 22.0;
uniform float moon_diameter_deg : hint_range(0.1, 5.0) = 1.2;
uniform vec3 moon_color : source_color = vec3(0.9);
uniform float moon_phase_deg : hint_range(0.0, 180.0) = 55.0;
uniform float moon_maria : hint_range(0.0, 1.0) = 0.35;
uniform float moon_maria_scale = 3.0;
uniform float moon_glow : hint_range(0.0, 2.0) = 0.35;
uniform float moon_glow_width_deg : hint_range(0.1, 30.0) = 3.0;
uniform float moon_halo : hint_range(0.0, 1.0) = 0.1;
uniform float moon_halo_width_deg : hint_range(1.0, 90.0) = 20.0;
uniform float lightning_flash : hint_range(0.0, 2.0) = 0.0;
uniform vec3 lightning_direction = vec3(0.0, 0.3, -1.0);
uniform float lightning_spread_deg : hint_range(1.0, 90.0) = 25.0;
uniform float lightning_ambient : hint_range(0.0, 1.0) = 0.25;

const float HALF_PI = 1.5707963;
const float EDGE_SOFTNESS = 0.08;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(0.0, 1.0, fract(p));
	return mix(
		mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

vec3 atmosphere(vec3 direction) {
	float v_angle = acos(clamp(direction.y, -1.0, 1.0));
	float c = 1.0 - v_angle / HALF_PI;
	if (direction.y >= 0.0) {
		return mix(sky_horizon_color, sky_top_color, clamp(1.0 - pow(1.0 - c, 1.0 / sky_curve), 0.0, 1.0));
	}
	float g = -c;
	return mix(ground_horizon_color, ground_bottom_color, clamp(1.0 - pow(1.0 - g, 1.0 / ground_curve), 0.0, 1.0));
}

vec3 moon_direction() {
	float bearing = radians(moon_bearing_deg);
	float elevation = radians(moon_elevation_deg);
	return vec3(sin(bearing) * cos(elevation), sin(elevation), -cos(bearing) * cos(elevation));
}

void sky() {
	vec3 colour = atmosphere(EYEDIR);

	vec3 toward = moon_direction();
	float off_moon = degrees(acos(clamp(dot(EYEDIR, toward), -1.0, 1.0)));
	colour += moon_color * (
		moon_glow * exp(-off_moon / moon_glow_width_deg)
		+ moon_halo * exp(-off_moon / moon_halo_width_deg)
	);
	vec3 right = normalize(cross(toward, vec3(0.0, 1.0, 0.0)));
	vec3 up = cross(right, toward);
	float radius = radians(moon_diameter_deg) * 0.5;
	vec2 disc = vec2(dot(EYEDIR, right), dot(EYEDIR, up)) / radius;
	float from_centre = length(disc);
	if (dot(EYEDIR, toward) > 0.0 && from_centre < 1.0 + EDGE_SOFTNESS) {
		vec3 surface = vec3(disc, sqrt(max(1.0 - from_centre * from_centre, 0.0)));
		float phase = radians(moon_phase_deg);
		vec3 sun = vec3(sin(phase), 0.0, cos(phase));
		float lit = smoothstep(-0.05, 0.25, dot(surface, sun));
		float maria = 1.0 - moon_maria * value_noise(disc * moon_maria_scale);
		vec3 moon = moon_color * lit * maria;
		float coverage = 1.0 - smoothstep(1.0 - EDGE_SOFTNESS, 1.0 + EDGE_SOFTNESS, from_centre);
		colour = mix(colour, moon, coverage);
	}
	float off_bolt = degrees(acos(clamp(dot(EYEDIR, normalize(lightning_direction)), -1.0, 1.0)));
	colour += lightning_flash * (lightning_ambient + exp(-off_bolt / lightning_spread_deg));
	COLOR = colour;
}
