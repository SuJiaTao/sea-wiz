shader_type spatial;
render_mode unshaded, shadows_disabled;

#include "res://shaders/sunset.gdshaderinc"

// Dark swell under a low sun: each wave face mirrors the sunset sky, and a
// broken path of glitter runs from the sun toward us until it slips under.

uniform float sun_elevation_deg = 3.0;
uniform float sun_bearing_deg = 270.0;
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
uniform vec3 deep_water : source_color = vec3(0.006, 0.006, 0.012);
uniform float wave_scale = 0.1;
uniform float wave_tilt = 0.1;
uniform float glitter_sharpness = 900.0;
uniform float glitter_strength = 5.0;

const int WAVE_OCTAVES = 9;
const float SLOPE_KEEP = 0.82;
const float WAVE_SPEED = 0.9;
const vec3 GLINT_COLOUR = vec3(1.0, 0.5, 0.15);
// The glitter path dies as the last of the disc slips under.
const float SUN_RADIUS_DEG = 0.6;
// Even at a grazing angle the sea stays a little darker than the sky, so the
// horizon line holds and the sun visibly sinks into it.
const float HORIZON_REFLECTION = 0.62;
const float ROUGH_SHADOWING = 0.35;
const float REFLECTION_SPREAD = 0.035;
const int SKY_TAPS = 4;
// How readily far faces hide behind nearer ones at a grazing angle.
const float MASKING = 0.5;
// The far glitter path is much taller than it is wide.
const float COLUMN_NARROWING = 0.06;
// Below 0.5 the far column keeps more of its brightness than a true spread would.
const float COLUMN_FALLOFF = 0.3;
const float FINE_CHOP = 0.7;
const float FINE_VARIANCE = 0.08;
const float STREAK_WIDTH = 6.0;
const float STREAK_ROWS = 4000.0;
const float STREAK_DRIFT = 0.15;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Ripples finer than a pixel are faded out rather than left to shimmer.
float resolved(float footprint, float frequency) {
	return 1.0 - smoothstep(0.25, 0.9, footprint * frequency);
}

// Waves too fine for a pixel are not drawn, but they are not thrown away
// either: what they would have done to the slope is kept as a spread, so the
// far sea goes rough and matte the way real distant water does, instead of
// turning to a mirror.
vec3 slope(vec2 p, float footprint) {
	vec2 s = vec2(0.0);
	float lost = 0.0;
	float amplitude = 1.0;
	float frequency = 1.0;
	// Small ripples are nearly as steep as big swells, so they break the
	// reflection into fine chop instead of leaving broad smooth slicks.
	for (int octave = 0; octave < WAVE_OCTAVES; octave++) {
		float angle = float(octave) * 2.39;
		vec2 heading = vec2(cos(angle), sin(angle));
		float phase = dot(p, heading) * frequency + TIME * WAVE_SPEED * sqrt(frequency);
		float shown = resolved(footprint, frequency);
		s += heading * cos(phase) * amplitude * shown;
		lost += amplitude * amplitude * 0.5 * (1.0 - shown);
		frequency *= 1.85;
		amplitude *= SLOPE_KEEP;
	}
	float fine_shown = resolved(footprint, 6.0);
	vec2 fine = vec2(sunset_noise(p * 6.0 + TIME), sunset_noise(p * 6.0 - TIME + 7.0)) - 0.5;
	s += fine * FINE_CHOP * fine_shown;
	lost += FINE_CHOP * FINE_CHOP * FINE_VARIANCE * (1.0 - fine_shown);
	return vec3(s, lost);
}

void fragment() {
	vec3 sun = sunset_sun_direction(sun_elevation_deg, sun_bearing_deg);
	vec3 eye = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 view = normalize(world_position - eye);
	vec2 p = world_position.xz * wave_scale;
	float footprint = length(fwidth(p));
	vec3 waves = slope(p, footprint);
	vec2 tilt = waves.xy * wave_tilt;
	float spread = sqrt(waves.z) * wave_tilt;
	vec3 normal = normalize(vec3(-tilt.x, 1.0, -tilt.y));
	vec3 mirrored = reflect(view, normal);
	mirrored.y = abs(mirrored.y);
	// Faint long streaks along the horizon where the hidden swells bunch up.
	vec2 out_to = world_position.xz - eye.xz;
	vec2 heading = normalize(view.xz);
	float along = max(dot(out_to, heading), 1.0);
	float across = dot(out_to, vec2(-heading.y, heading.x));
	float streak = sunset_fbm(vec2(across / along * STREAK_WIDTH, STREAK_ROWS / along + TIME * STREAK_DRIFT));
	spread *= 0.6 + 0.8 * streak;
	// Each facet sees a patch of sky, not a single ray: the rougher the
	// surface, the further up and down that patch reaches.
	float reach = REFLECTION_SPREAD + 2.0 * spread;
	vec3 sky = vec3(0.0);
	for (int i = 0; i < SKY_TAPS; i++) {
		float offset = (float(i) / float(SKY_TAPS - 1) - 0.3) * reach;
		vec3 tap = normalize(vec3(mirrored.x, abs(mirrored.y + offset), mirrored.z));
		sky += sunset_sky(tap, sun, daylight, TIME, false);
	}
	sky /= float(SKY_TAPS);
	// Rough water seen almost edge-on hides its own far faces and turns its
	// near faces toward us, which reflect less, so it reads darker than the sky.
	float grazing = max(-view.y, 0.0);
	float hidden = smoothstep(0.0, 1.0, spread / max(grazing, 0.001) * MASKING);
	float facing_us = max(dot(-view, normal), mix(0.0, spread * 2.0, hidden));
	float fresnel = 0.04 + HORIZON_REFLECTION * pow(1.0 - facing_us, 5.0);
	fresnel *= 1.0 - ROUGH_SHADOWING * hidden;
	// The sun's glitter: one sharp glint per drawn facet up close, widening
	// into a tall column of sparkle far off where the facets are too small to draw.
	float above = smoothstep(-SUN_RADIUS_DEG, SUN_RADIUS_DEG, sunset_elevation(sun));
	float base = 1.0 / glitter_sharpness;
	float tall = base + 4.0 * spread * spread;
	float wide = base + 4.0 * spread * spread * COLUMN_NARROWING;
	float rise = mirrored.y - sun.y;
	vec2 flat_mirror = normalize(mirrored.xz);
	vec2 flat_sun = normalize(sun.xz);
	float aside = (flat_mirror.x * flat_sun.y - flat_mirror.y * flat_sun.x);
	float lobe = exp(-0.5 * (rise * rise / tall + aside * aside / wide)) * pow(base * base / (tall * wide), COLUMN_FALLOFF);
	float sparkle = mix(1.0, streak * 1.8, smoothstep(0.0, 0.02, spread));
	float glint = lobe * sparkle * glitter_strength * above * daylight;
	ALBEDO = mix(deep_water, sky, fresnel) + GLINT_COLOUR * glint;
}
