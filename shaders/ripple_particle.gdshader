shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

#include "res://shaders/particle_curves.gdshaderinc"

uniform float ring_radius : hint_range(0.1, 1.0) = 0.85;
uniform float ring_width : hint_range(0.01, 0.5) = 0.12;
uniform float foam : hint_range(0.0, 1.0) = 0.35;
uniform float foam_scale = 6.0;

const float SEED_SPREAD = 37.0;

varying float ripple_progress;
varying float ripple_seed;

void vertex() {
	ripple_progress = INSTANCE_CUSTOM.x;
	ripple_seed = INSTANCE_CUSTOM.y;
	VERTEX.xz *= particle_size(1.0, ripple_progress, 0.0);
}

void fragment() {
	float from_centre = length(UV * 2.0 - 1.0);
	float ring = 1.0 - smoothstep(0.0, ring_width, abs(from_centre - ring_radius));
	float churned = billow_noise(UV * foam_scale + ripple_seed * SEED_SPREAD);
	float inside = (1.0 - smoothstep(ring_radius - ring_width, ring_radius, from_centre)) * foam * churned;
	ALBEDO = display_to_linear(particle_heat(ripple_progress));
	ALPHA = particle_alpha(ripple_progress) * max(ring * churned, inside);
}
