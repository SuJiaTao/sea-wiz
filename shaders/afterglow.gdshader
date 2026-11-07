shader_type canvas_item;
render_mode unshaded, blend_disabled;

// Phosphor afterglow: the screen keeps a fading copy of every bright frame,
// so fast lights leave short trails.

uniform sampler2D previous : hint_screen_texture, filter_linear, repeat_disable;
uniform float decay : hint_range(0.0, 0.99) = 0.82;

void fragment() {
	vec3 current = texture(TEXTURE, UV).rgb;
	vec3 held = texture(previous, SCREEN_UV).rgb * decay;
	COLOR = vec4(max(current, held), 1.0);
}
