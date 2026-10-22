shader_type canvas_item;
render_mode unshaded, blend_disabled;

// Detector lag: hot things leave a decaying trail, cooler ones update at once.
// Drawn into a buffer that is never cleared, so the screen texture still
// holds the previous frame when this runs.

uniform sampler2D previous_frame : hint_screen_texture, filter_nearest;
uniform float retention : hint_range(0.0, 1.0) = 0.0;
uniform float trail_floor : hint_range(0.0, 1.0) = 0.2;
uniform float trail_full : hint_range(0.0, 1.0) = 0.6;

const vec3 LUMA = vec3(0.30, 0.59, 0.11);

void fragment() {
	vec3 current = texture(TEXTURE, UV).rgb;
	vec3 previous = texture(previous_frame, SCREEN_UV).rgb;
	float heat = smoothstep(trail_floor, trail_full, dot(previous, LUMA));
	COLOR = vec4(max(current, previous * retention * heat), 1.0);
}
