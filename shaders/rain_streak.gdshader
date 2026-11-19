shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

// Rain drops in a box that travels with the camera. Each drop falls forever,
// wrapping inside the box, and is drawn as a short streak along its fall.
// Drops differ a little in speed, length and brightness, and fade with range.
// Only drops on the moon's side of the ship catch the light; the rest are dim.

uniform vec3 centre = vec3(0.0);
uniform vec3 box_size = vec3(80.0, 50.0, 80.0);
uniform vec3 fall_velocity = vec3(2.5, -20.0, 1.0);
uniform float streak_seconds = 0.1;
uniform float width_pixels : hint_range(0.5, 4.0) = 1.0;
uniform float brightness : hint_range(0.0, 1.0) = 0.24;
uniform float speed_spread : hint_range(0.0, 0.5) = 0.25;
uniform float length_spread : hint_range(0.0, 1.0) = 0.6;
uniform float brightness_spread : hint_range(0.0, 1.0) = 0.6;
uniform float fade_range = 45.0;
uniform float moon_bearing_deg = 75.0;
uniform float shadow_level : hint_range(0.0, 1.0) = 0.3;

varying float along;
varying float shine;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

vec3 wrapped(vec3 position) {
	return centre + mod(position - centre + box_size * 0.5, box_size) - box_size * 0.5;
}

void vertex() {
	vec3 seed = MODEL_MATRIX[3].xyz;
	float roll = hash(seed);
	vec3 velocity = fall_velocity * (1.0 + (roll - 0.5) * 2.0 * speed_spread);
	vec3 drop = wrapped(seed + velocity * TIME);
	float streak = streak_seconds * (1.0 + (hash(seed.zxy) - 0.5) * 2.0 * length_spread);
	vec3 head = (VIEW_MATRIX * vec4(drop, 1.0)).xyz;
	vec3 tail = (VIEW_MATRIX * vec4(drop - velocity * streak, 1.0)).xyz;
	vec2 moonward = vec2(sin(radians(moon_bearing_deg)), -cos(radians(moon_bearing_deg)));
	vec2 from_ship = drop.xz - centre.xz;
	float moonlit = mix(shadow_level, 1.0, smoothstep(-0.2, 0.5, dot(normalize(from_ship + vec2(1e-3)), moonward)));
	shine = moonlit * (1.0 - (hash(seed.yzx) * brightness_spread)) * (1.0 - smoothstep(fade_range * 0.4, fade_range, length(head)));
	vec2 axis = normalize(head.xy - tail.xy + vec2(0.0, 1e-4));
	vec2 side = vec2(-axis.y, axis.x);
	float pixel_angle = 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float width = length(head) * pixel_angle * width_pixels;
	along = VERTEX.y + 0.5;
	VERTEX = mix(tail, head, along) + vec3(side * VERTEX.x * width, 0.0);
}

void fragment() {
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	ALBEDO = vec3(pow(brightness, 2.2)) * along * across * shine;
}
