shader_type spatial;
render_mode unshaded, shadows_disabled;

#include "res://shaders/sunset.gdshaderinc"

// The sea just after sunset. Long swells really lift the water, with crests
// a little sharper than their troughs. On top, the same wave normal map the
// game's ocean uses crosses in several sheets for the fine surface. Every
// wave face mirrors the sky above it: faces tipped toward us catch blue sky
// and go dark, faces tipped away catch the glow low on the horizon and light
// up in long streaks, brightest under where the sun went down. Detail too
// fine for a pixel is kept as roughness, so far water stays matte and a
// little darker than the sky, and the horizon holds a clean edge.

uniform float glow_bearing_deg = 93.0;
uniform float dusk : hint_range(0.0, 1.0) = 0.0;
uniform vec3 deep_water : source_color = vec3(0.01, 0.02, 0.04);
uniform sampler2D wave_normals : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float swell_height = 0.8;
uniform float detail_strength = 0.2;
uniform float wind_bearing_deg = 60.0;

const int SWELLS = 4;
const float SWELL_LENGTHS[4] = float[](60.0, 38.0, 24.0, 15.0);
const float SWELL_SHARES[4] = float[](1.0, 0.6, 0.35, 0.2);
const float SWELL_ANGLES[4] = float[](0.0, 0.5, -0.45, 0.9);
// Gerstner steepness: how far each crest leans in toward a point.
const float SWELL_STEEPNESS = 0.55;
const float GRAVITY = 9.8;
// The swells are shaded a little gentler than their true slope, so the faces
// turned toward us do not all drop to the darkest sky overhead.
const float SWELL_SHADING = 0.6;
// The mesh stops lifting the swells well before the horizon, where the water
// drops just under the far sheet so the two meet without a seam.
const float SWELL_FADE_START = 250.0;
const float SWELL_FADE_END = 650.0;
const float FAR_DROP = 1.0;

const int DETAIL_LAYERS = 4;
const float DETAIL_TILES[4] = float[](40.0, 14.0, 6.0, 2.5);
const float DETAIL_ANGLES[4] = float[](0.3, 0.0, 0.65, -0.55);
const float DETAIL_SPEEDS[4] = float[](2.6, 1.9, 1.4, 1.0);
const float DETAIL_SHARES[4] = float[](0.7, 1.0, 0.8, 0.6);
const float DETAIL_STRETCH = 0.45;

// Even at a grazing angle the sea stays a little darker than the sky.
const float HORIZON_REFLECTION = 0.6;
// Higher than clear water really gives, so the sea right under the deck still
// shows its waves and the rail stands out against it.
const float BASE_REFLECTION = 0.24;
const float ROUGH_SHADOWING = 0.35;
const float MASKING = 0.5;
// Open sea never gets rougher than a fresh breeze makes it.
const float MAX_VARIANCE = 0.03;
// How far up and down each facet's patch of sky reaches. Wide enough to soften
// the jump from dark to bright across a wave face.
const float REFLECTION_SPREAD = 0.08;
// Far off, the unseen wave faces that tip toward us mirror sky well above the
// horizon (a tilt of a few degrees doubles in the reflection), and at a
// grazing angle those are the faces we see most. So the far sea mixes deep
// blue sky in with the glow instead of mirroring only the horizon.
const float TILT_REACH = 4.0;
const int SKY_TAPS = 5;
const float LINE_SHARE = 0.6;
const float LINE_WIDTH = 90.0;
const float LINE_ROWS = 6000.0;
const float LINE_DRIFT = 0.3;

varying vec2 rest_xz;
varying vec3 world_position;

float swell_fade(vec2 xz, vec3 eye) {
	return 1.0 - smoothstep(SWELL_FADE_START, SWELL_FADE_END, distance(xz, eye.xz));
}

vec2 swell_heading(int i) {
	float angle = radians(wind_bearing_deg) + SWELL_ANGLES[i];
	return vec2(sin(angle), -cos(angle));
}

float swell_phase(int i, vec2 xz, out float k) {
	k = TAU / SWELL_LENGTHS[i];
	return k * dot(swell_heading(i), xz) - sqrt(GRAVITY * k) * TIME;
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	rest_xz = world.xz;
	float fade = swell_fade(world.xz, CAMERA_POSITION_WORLD);
	vec3 lift = vec3(0.0);
	for (int i = 0; i < SWELLS; i++) {
		float k;
		float phase = swell_phase(i, world.xz, k);
		float a = swell_height * SWELL_SHARES[i];
		vec2 lean = swell_heading(i) * SWELL_STEEPNESS / (k * float(SWELLS)) * cos(phase) * SWELL_SHARES[i];
		lift += vec3(lean.x, a * sin(phase), lean.y);
	}
	world += lift * fade;
	world.y -= FAR_DROP * (1.0 - fade);
	world_position = world;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
}

// The swells are shaded all the way to the horizon, even where the mesh no
// longer lifts them. Once a swell is too short to see across a few pixels
// it is not drawn; its slope is kept as roughness instead (z).
vec3 swell_slope(vec2 xz, float footprint) {
	vec3 s = vec3(0.0);
	for (int i = 0; i < SWELLS; i++) {
		float k;
		float phase = swell_phase(i, xz, k);
		float a = swell_height * SWELL_SHARES[i];
		// Leaning crests pinch the slope near the top and spread it in the trough.
		float pinch = 1.0 - SWELL_STEEPNESS / float(SWELLS) * SWELL_SHARES[i] * sin(phase);
		float shown = 1.0 - smoothstep(0.1, 1.0, footprint / SWELL_LENGTHS[i]);
		s.xy += swell_heading(i) * k * a * cos(phase) / max(pinch, 0.2) * shown * SWELL_SHADING;
		s.z += k * k * a * a * 0.5 * (1.0 - shown);
	}
	return s;
}

// One sheet of the wave map, stretched across its heading so ripples run in
// long lines. Returns the slope and how much the mipmaps flattened it.
vec3 detail_layer(vec2 xz, int i) {
	float angle = radians(wind_bearing_deg) + DETAIL_ANGLES[i];
	vec2 heading = vec2(sin(angle), -cos(angle));
	vec2 across = vec2(-heading.y, heading.x);
	vec2 uv = vec2(dot(xz, across) * DETAIL_STRETCH, dot(xz, heading) - DETAIL_SPEEDS[i] * TIME) / DETAIL_TILES[i];
	vec3 n = texture(wave_normals, uv).xyz * 2.0 - 1.0;
	float kept = clamp(length(n), 0.05, 1.0);
	vec2 local = n.xy / max(n.z, 0.2) * vec2(DETAIL_STRETCH, 1.0);
	float strength = detail_strength * DETAIL_SHARES[i];
	// Toksvig: a short averaged normal means slopes were lost to filtering.
	float lost = (1.0 - kept) / kept;
	return vec3((across * local.x + heading * local.y) * strength, lost * strength * strength);
}

void fragment() {
	vec3 glow = sunset_glow_direction(glow_bearing_deg);
	vec3 eye = CAMERA_POSITION_WORLD;
	vec3 view = normalize(world_position - eye);
	vec3 swells = swell_slope(rest_xz, length(fwidth(rest_xz)));
	vec2 slope = swells.xy;
	float variance = swells.z;
	for (int i = 0; i < DETAIL_LAYERS; i++) {
		vec3 layer = detail_layer(rest_xz, i);
		slope += layer.xy;
		variance += layer.z;
	}
	variance = min(variance, MAX_VARIANCE);
	// Waves too small to draw still show far off as thin lines of crests
	// running along the horizon, each about a pixel deep. Most of the lost
	// slope goes back in as those lines, so the far sea keeps the same
	// texture and contrast as the near sea instead of going flat.
	vec2 out_to = rest_xz - eye.xz;
	vec2 heading = normalize(view.xz);
	float along = max(dot(out_to, heading), 1.0);
	float across = dot(out_to, vec2(-heading.y, heading.x));
	float lines = sunset_fbm(vec2(across / along * LINE_WIDTH, LINE_ROWS / along + TIME * LINE_DRIFT)) * 2.0 - 1.0;
	slope -= heading * lines * sqrt(variance) * LINE_SHARE;
	variance *= 1.0 - LINE_SHARE;
	float spread = sqrt(variance);
	vec3 normal = normalize(vec3(-slope.x, 1.0, -slope.y));
	vec3 mirrored = reflect(view, normal);
	mirrored.y = abs(mirrored.y);

	// Each facet sees a patch of sky: the rougher, the further it reaches.
	float reach = REFLECTION_SPREAD + spread * TILT_REACH;
	vec3 sky = vec3(0.0);
	for (int i = 0; i < SKY_TAPS; i++) {
		float offset = (float(i) / float(SKY_TAPS - 1) - 0.15) * reach;
		vec3 tap = normalize(vec3(mirrored.x, abs(mirrored.y + offset), mirrored.z));
		sky += sunset_sky(tap, glow, dusk);
	}
	sky /= float(SKY_TAPS);

	// Rough water seen almost edge-on hides its own far faces and turns its
	// near faces toward us, which reflect less, so it reads darker than the sky.
	float grazing = max(-view.y, 0.0);
	float hidden = smoothstep(0.0, 1.0, spread / max(grazing, 0.001) * MASKING);
	float facing_us = max(dot(-view, normal), mix(0.0, spread * 2.0, hidden));
	float fresnel = BASE_REFLECTION + HORIZON_REFLECTION * pow(1.0 - facing_us, 5.0);
	fresnel *= 1.0 - ROUGH_SHADOWING * hidden;
	ALBEDO = mix(deep_water, sky, fresnel);
}
