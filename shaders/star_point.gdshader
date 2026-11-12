shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, skip_vertex_transform;

// A point of light that stays at least point_size_pixels wide at any distance or zoom,
// so a star and a far-off missile look identical until the missile is close.
// Starfield multimesh stars carry their own brightness and size in the custom
// data, and zooming in gathers more light so fainter stars come out.

instance uniform float brightness = 0.7;
instance uniform float twinkle = 1.0;
uniform float point_size_pixels : hint_range(0.5, 16.0) = 2.5;
uniform float twinkle_rate = 5.0;
uniform float twinkle_depth : hint_range(0.0, 1.0) = 0.5;
uniform float softness = 3.0;
uniform float visibility : hint_range(0.0, 1.0) = 1.0;
uniform float cloud_shade : hint_range(0.0, 1.0) = 0.0;
uniform float wide_focal = 1.5697;
uniform float zoom_gather : hint_range(0.0, 1.5) = 1.0;

const float CUSTOM_FLAG = 0.5;

varying float glow;

float hash13(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	vec4 centre = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	float pixel_angle = 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	bool catalogued = INSTANCE_CUSTOM.a > CUSTOM_FLAG;
	float pixels = catalogued ? INSTANCE_CUSTOM.g : point_size_pixels;
	float size = length(centre.xyz) * pixel_angle * pixels;
	VERTEX = centre.xyz + vec3(VERTEX.xy * size, 0.0);

	float seed = hash13(NODE_POSITION_WORLD);
	float shimmer = sin(TIME * twinkle_rate * (0.6 + seed) + seed * 40.0)
		* sin(TIME * twinkle_rate * 1.37 + seed * 17.0);
	float shine = brightness;
	float flicker = twinkle;
	if (catalogued) {
		float zoom = PROJECTION_MATRIX[1][1] / wide_focal;
		shine = min(INSTANCE_CUSTOM.r * pow(zoom, zoom_gather), 1.0);
		flicker = INSTANCE_CUSTOM.b;
	}
	glow = visibility * (1.0 - cloud_shade) * shine * (1.0 - flicker * twinkle_depth * (0.5 + 0.5 * shimmer));
}

void fragment() {
	vec2 offset = (UV - 0.5) * 2.0;
	ALBEDO = vec3(pow(glow, 2.2)) * exp(-dot(offset, offset) * softness);
}
