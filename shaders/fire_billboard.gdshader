shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D fire_heat : filter_linear, repeat_enable;
uniform sampler2D palette : source_color, filter_linear, repeat_disable;
uniform float window : hint_range(0.05, 1.0) = 0.35;
uniform float intensity = 1.4;
uniform float side_fade : hint_range(0.0, 0.5) = 0.08;
uniform float taper : hint_range(0.0, 2.0) = 0.7;

instance uniform float strength = 1.0;
instance uniform float column = 0.0;

const float MAX_HEAT = 36.0;
const float BYTE_RANGE = 255.0;
const float MIN_STRENGTH = 0.001;

void vertex() {
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
	vec3 facing = cross(right, up);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(right * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(up * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(facing * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]
	);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float half_texel = 0.5 / float(textureSize(fire_heat, 0).y);
	vec2 uv = vec2(column + UV.x * window, clamp(UV.y, half_texel, 1.0 - half_texel));
	float heat = texture(fire_heat, uv).r * BYTE_RANGE / MAX_HEAT;
	heat = (heat - (1.0 - strength)) / max(strength, MIN_STRENGTH);
	heat -= taper * pow(abs(UV.x * 2.0 - 1.0), 2.0);
	heat *= smoothstep(0.0, side_fade, UV.x) * smoothstep(1.0, 1.0 - side_fade, UV.x);
	if (heat <= 0.0) {
		discard;
	}
	vec4 colour = texture(palette, vec2(clamp(heat, 0.0, 1.0), 0.5));
	ALBEDO = colour.rgb * intensity;
	ALPHA = colour.a;
}
