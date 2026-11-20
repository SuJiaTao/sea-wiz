shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

#include "res://shaders/particle_curves.gdshaderinc"
#include "res://shaders/billboard_particle.gdshaderinc"
#include "res://shaders/moon_shadow.gdshaderinc"

uniform float shadow_level : hint_range(0.0, 1.0) = 0.3;

varying float moonlight;

uniform float billow : hint_range(0.0, 1.0) = 0.5;
uniform float erosion : hint_range(0.0, 1.0) = 0.5;
uniform float softness : hint_range(0.05, 1.0) = 0.45;
uniform float noise_scale = 3.0;
uniform float churn = 0.6;
// Sky glow scattered by the smoke, so cold smoke never reads darker
// than the horizon behind it.
uniform float skylight : hint_range(0.0, 0.5) = 0.16;
// Fade where a puff meets the sea or a hull instead of cutting off in a line.
uniform float soft_distance = 6.0;
uniform float soft_growth = 0.01;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

const float SEED_SPREAD = 37.0;
const float EROSION_EDGE = 0.2;

float soft_contact(vec2 screen_uv, vec3 fragment, mat4 inverse_projection) {
	float depth = texture(depth_texture, screen_uv).x;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(screen_uv, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth);
#endif
	vec4 behind = inverse_projection * vec4(ndc, 1.0);
	float room = fragment.z - behind.z / behind.w;
	return clamp(room / (soft_distance - fragment.z * soft_growth), 0.0, 1.0);
}

void vertex() {
	particle_progress = INSTANCE_CUSTOM.x;
	particle_seed = INSTANCE_CUSTOM.y;
	particle_level = particle_heat(particle_progress);
	particle_opacity = particle_alpha(particle_progress);
	moonlight = moon_light_at(MODEL_MATRIX[3].xyz, shadow_level);
	VERTEX = billboard_vertex(VERTEX, MODEL_MATRIX, VIEW_MATRIX, particle_progress, particle_seed);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 from_centre = UV * 2.0 - 1.0;
	vec2 drift = vec2(particle_seed * SEED_SPREAD, particle_progress * churn);
	float n = billow_noise(UV * noise_scale + drift);
	float edge = length(from_centre) + (n - 0.5) * billow;
	float body = 1.0 - smoothstep(1.0 - softness, 1.0, edge);
	float worn = particle_progress * erosion;
	float remaining = smoothstep(worn, worn + EROSION_EDGE, n);
	ALBEDO = display_to_linear(max(particle_level, skylight) * moonlight);
	ALPHA = particle_opacity * body * remaining * soft_contact(SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX);
}
