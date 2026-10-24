shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

// Keeps every tracer at least min_pixels wide on screen at any zoom, so the
// stream stays a clean line out to the end of its flight instead of breaking up.

uniform float base_width = 0.11;
uniform float min_pixels : hint_range(0.0, 6.0) = 1.5;

void vertex() {
	float depth = -(MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).z;
	float pixel_angle = 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	VERTEX.xy *= max(1.0, depth * pixel_angle * min_pixels / base_width);
}

void fragment() {
	ALBEDO = COLOR.rgb;
}
