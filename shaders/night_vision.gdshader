shader_type canvas_item;

uniform sampler2D screen_texture: hint_screen_texture, filter_linear_mipmap;

uniform vec3 luminance: source_color = vec3(0.171, 0.171, 0.171);
uniform vec3 base_color: source_color = vec3(1.0, 1.0, 1.0);
uniform float brightness: hint_range(0.1, 10.0, 0.01) = 2;
uniform float noise_level: hint_range(0.0, 1.0, 0.01) = 0.28;
uniform float vignette_level: hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float edge_x: hint_range(0.0, 1.0, 0.01) = 0.15;
uniform float edge_y: hint_range(0.0, 6.0, 0.01) = 2.5;
uniform float flickering_level: hint_range(0.0, 1.0, 0.1) = 0.5;


float hash21(vec2 p) {
	p = fract(p * vec2(233.34, 851.73));
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV - 0.5;
	vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;
	uv.x *= resolution.x / resolution.y;
	float time = TIME;
	vec3 color = texture(screen_texture, UV).rgb;
	float grain = value_noise(uv * 400.0);
	color += hash21(uv * time) * noise_level * 0.5;
	vec2 edge = uv * uv *  uv * vec2(edge_x, edge_y);
	color *= smoothstep(length(edge), 1 , vignette_level);
	float flicker_intensity = hash21(uv * time) * flickering_level;
	vec3 vision_color = base_color + (base_color * flicker_intensity);
	color = dot(color, luminance) * vision_color;
	COLOR = vec4(color * brightness, 1.0);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
