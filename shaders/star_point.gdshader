shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, skip_vertex_transform;

// A point of light that stays at least point_size_pixels wide at any distance or zoom,
// so a star and a far-off missile look identical until the missile is close.

instance uniform float brightness = 0.7;
instance uniform float twinkle = 1.0;
uniform float point_size_pixels : hint_range(0.5, 16.0) = 2.0;
uniform float twinkle_rate = 5.0;
uniform float twinkle_depth : hint_range(0.0, 1.0) = 0.5;
uniform float softness = 3.0;

varying float glow;

float hash13(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	vec4 centre = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	float pixel_angle = 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float size = length(centre.xyz) * pixel_angle * point_size_pixels;
	VERTEX = centre.xyz + vec3(VERTEX.xy * size, 0.0);

	float seed = hash13(NODE_POSITION_WORLD);
	float shimmer = sin(TIME * twinkle_rate * (0.6 + seed) + seed * 40.0)
		* sin(TIME * twinkle_rate * 1.37 + seed * 17.0);
	glow = brightness * (1.0 - twinkle * twinkle_depth * (0.5 + 0.5 * shimmer));
}

void fragment() {
	vec2 offset = (UV - 0.5) * 2.0;
	ALBEDO = vec3(pow(glow, 2.2)) * exp(-dot(offset, offset) * softness);
}
