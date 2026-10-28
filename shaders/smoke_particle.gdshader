shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

#include "res://shaders/particle_curves.gdshaderinc"
#include "res://shaders/billboard_particle.gdshaderinc"

uniform float billow : hint_range(0.0, 1.0) = 0.5;
uniform float erosion : hint_range(0.0, 1.0) = 0.5;
uniform float softness : hint_range(0.05, 1.0) = 0.45;
uniform float noise_scale = 3.0;
uniform float churn = 0.6;

const float SEED_SPREAD = 37.0;
const float EROSION_EDGE = 0.2;

void vertex() {
	particle_progress = INSTANCE_CUSTOM.x;
	particle_seed = INSTANCE_CUSTOM.y;
	particle_level = particle_heat(particle_progress);
	particle_opacity = particle_alpha(particle_progress);
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
	ALBEDO = display_to_linear(particle_level);
	ALPHA = particle_opacity * body * remaining;
}
