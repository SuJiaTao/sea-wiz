shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// Each tracer is drawn from the round backwards: full heat at the round,
// fading to nothing at the tail, at least min_pixels wide at any zoom.

uniform float base_width = 0.11;
uniform float min_pixels : hint_range(0.0, 6.0) = 1.5;
uniform float tail_falloff : hint_range(0.5, 6.0) = 2.0;

varying float along_tail;

void vertex() {
	along_tail = VERTEX.z + 0.5;
	VERTEX.z += 0.5;
	float depth = -(MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).z;
	float pixel_angle = 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	VERTEX.xy *= max(1.0, depth * pixel_angle * min_pixels / base_width);
}

void fragment() {
	ALBEDO = COLOR.rgb * pow(1.0 - clamp(along_tail, 0.0, 1.0), tail_falloff);
}
