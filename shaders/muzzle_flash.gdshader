shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// A muzzle flash that always faces the camera: a hot round core with a few
// soft rays that change every frame, fading to nothing before the quad edge.

uniform vec3 heat = vec3(3.2, 3.2, 2.8);
uniform float rays = 6.0;
uniform float ray_sharpness : hint_range(1.0, 16.0) = 6.0;
uniform float ray_share : hint_range(0.0, 1.0) = 0.6;
uniform float core_tightness = 12.0;

const float FLICKER_RATE = 60.0;
const float FLICKER_TURN = 1.7;

void vertex() {
	float size = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * size, INV_VIEW_MATRIX[1] * size, INV_VIEW_MATRIX[2] * size, MODEL_MATRIX[3]
	);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x) + floor(TIME * FLICKER_RATE) * FLICKER_TURN;
	float ray = pow(abs(cos(angle * rays * 0.5)), ray_sharpness) * exp(-r * 3.0);
	float core = exp(-r * r * core_tightness);
	float edge = 1.0 - smoothstep(0.6, 1.0, r);
	ALBEDO = heat * (core + ray * ray_share) * edge;
}
