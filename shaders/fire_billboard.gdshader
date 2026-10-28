shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D fire_heat : filter_linear, repeat_enable;
uniform sampler2D palette : source_color, filter_linear, repeat_disable;
uniform float intensity = 1.0;
uniform float side_fade : hint_range(0.0, 0.5) = 0.25;
uniform float blur_texels : hint_range(0.0, 4.0) = 2.5;

instance uniform float strength = 1.0;
instance uniform float column = 0.0;

const float MAX_HEAT = 36.0;
const float BYTE_RANGE = 255.0;
const float MIN_STRENGTH = 0.001;
const float CENTRE_WEIGHT = 0.2;
const float NEIGHBOUR_WEIGHT = 0.12;
const float CORNER_WEIGHT = 0.08;

varying float span;

void vertex() {
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
	vec3 facing = cross(right, up);
	float width = length(MODEL_MATRIX[0].xyz);
	float height = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(right * width, 0.0),
		vec4(up * height, 0.0),
		vec4(facing * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]
	);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	vec2 grid = vec2(textureSize(fire_heat, 0));
	span = (width / height) * (grid.y / grid.x);
}

void fragment() {
	vec2 texel = blur_texels / vec2(textureSize(fire_heat, 0));
	vec2 uv = vec2(column + UV.x * span, clamp(UV.y, texel.y, 1.0 - texel.y));
	float sampled = texture(fire_heat, uv).r * CENTRE_WEIGHT
		+ texture(fire_heat, uv + vec2(texel.x, 0.0)).r * NEIGHBOUR_WEIGHT
		+ texture(fire_heat, uv - vec2(texel.x, 0.0)).r * NEIGHBOUR_WEIGHT
		+ texture(fire_heat, uv + vec2(0.0, texel.y)).r * NEIGHBOUR_WEIGHT
		+ texture(fire_heat, uv - vec2(0.0, texel.y)).r * NEIGHBOUR_WEIGHT
		+ texture(fire_heat, uv + texel).r * CORNER_WEIGHT
		+ texture(fire_heat, uv - texel).r * CORNER_WEIGHT
		+ texture(fire_heat, uv + vec2(texel.x, -texel.y)).r * CORNER_WEIGHT
		+ texture(fire_heat, uv + vec2(-texel.x, texel.y)).r * CORNER_WEIGHT;
	float heat = sampled * BYTE_RANGE / MAX_HEAT;
	heat = (heat - (1.0 - strength)) / max(strength, MIN_STRENGTH);
	heat *= smoothstep(0.0, side_fade, UV.x) * smoothstep(1.0, 1.0 - side_fade, UV.x);
	if (heat <= 0.0) {
		discard;
	}
	vec4 colour = texture(palette, vec2(clamp(heat, 0.0, 1.0), 0.5));
	ALBEDO = colour.rgb * intensity;
	ALPHA = colour.a;
}
