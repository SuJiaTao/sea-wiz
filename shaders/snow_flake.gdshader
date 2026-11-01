shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

// Snow flakes in a box that travels with the camera, drifting as they fall.

uniform vec3 centre = vec3(0.0);
uniform vec3 box_size = vec3(70.0, 45.0, 70.0);
uniform vec3 fall_velocity = vec3(0.6, -1.6, 0.3);
uniform float sway = 0.8;
uniform float flake_size = 0.09;
uniform float size_pixels : hint_range(0.5, 6.0) = 2.2;
uniform float brightness : hint_range(0.0, 1.0) = 0.6;

float hash13(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	vec3 base = MODEL_MATRIX[3].xyz;
	float seed = hash13(base);
	vec3 drift = vec3(sin(TIME * 0.7 + seed * 40.0), 0.0, cos(TIME * 0.5 + seed * 25.0)) * sway;
	vec3 flake = centre + mod(base + fall_velocity * TIME + drift - centre + box_size * 0.5, box_size) - box_size * 0.5;
	vec3 view = (VIEW_MATRIX * vec4(flake, 1.0)).xyz;
	float pixel_angle = 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float size = max(flake_size, length(view) * pixel_angle * size_pixels);
	VERTEX = view + vec3(VERTEX.xy * size, 0.0);
}

void fragment() {
	vec2 offset = (UV - 0.5) * 2.0;
	ALBEDO = vec3(pow(brightness, 2.2)) * max(1.0 - dot(offset, offset), 0.0);
}
