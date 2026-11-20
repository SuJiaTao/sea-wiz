shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// The tongue of fire out of the barrel: widest and hottest at the muzzle,
// tapering to a ragged point, a different length and shape every frame.

uniform vec3 heat = vec3(3.0, 2.8, 2.3);
uniform float flicker_rate = 60.0;

const float BASE_WIDTH = 0.9;
const float TAPER = 0.7;
const float SHORTEST = 0.55;
const float RAGGED = 0.25;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float frame = floor(TIME * flicker_rate);
	float along = 1.0 - UV.y;
	float reach = mix(SHORTEST, 1.0, hash(vec2(frame, 1.3)));
	float lick = (hash(vec2(frame, floor(along * 6.0))) - 0.5) * RAGGED;
	float width = BASE_WIDTH * pow(max(1.0 - along / reach, 0.0), TAPER);
	float across = abs(UV.x - 0.5) * 2.0 + lick * along;
	float body = clamp(1.0 - across / max(width, 0.001), 0.0, 1.0);
	float fade = pow(max(1.0 - along / reach, 0.0), 1.3);
	ALBEDO = heat * body * body * fade;
}
