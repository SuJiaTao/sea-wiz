shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

#include "res://shaders/particle_curves.gdshaderinc"
#include "res://shaders/billboard_particle.gdshaderinc"
#include "res://shaders/moon_shadow.gdshaderinc"

uniform float sharpness : hint_range(0.5, 6.0) = 2.0;
uniform float shadow_level : hint_range(0.0, 1.0) = 0.3;

varying float moonlight;

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
	float from_centre = length(UV * 2.0 - 1.0);
	float body = pow(clamp(1.0 - from_centre, 0.0, 1.0), sharpness);
	ALBEDO = display_to_linear(particle_level * moonlight);
	ALPHA = particle_opacity * body;
}
