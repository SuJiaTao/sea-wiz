shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

// Rain drops in a box that travels with the camera. Each drop falls forever,
// wrapping inside the box, and is drawn as a short streak along its fall.

uniform vec3 centre = vec3(0.0);
uniform vec3 box_size = vec3(80.0, 50.0, 80.0);
uniform vec3 fall_velocity = vec3(2.5, -20.0, 1.0);
uniform float streak_seconds = 0.1;
uniform float width_pixels : hint_range(0.5, 4.0) = 1.0;
uniform float brightness : hint_range(0.0, 1.0) = 0.24;

varying float along;

vec3 wrapped(vec3 position) {
	return centre + mod(position - centre + box_size * 0.5, box_size) - box_size * 0.5;
}

void vertex() {
	vec3 drop = wrapped(MODEL_MATRIX[3].xyz + fall_velocity * TIME);
	vec3 head = (VIEW_MATRIX * vec4(drop, 1.0)).xyz;
	vec3 tail = (VIEW_MATRIX * vec4(drop - fall_velocity * streak_seconds, 1.0)).xyz;
	vec2 axis = normalize(head.xy - tail.xy + vec2(0.0, 1e-4));
	vec2 side = vec2(-axis.y, axis.x);
	float pixel_angle = 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float width = length(head) * pixel_angle * width_pixels;
	along = VERTEX.y + 0.5;
	VERTEX = mix(tail, head, along) + vec3(side * VERTEX.x * width, 0.0);
}

void fragment() {
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	ALBEDO = vec3(pow(brightness, 2.2)) * along * across;
}
