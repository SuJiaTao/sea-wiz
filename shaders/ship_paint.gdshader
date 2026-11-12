shader_type spatial;
render_mode cull_disabled, ambient_light_disabled;

// Haze grey paint under a night sky: the open sky lights every face a little,
// more on the ones turned up, and the moonlight falls on the faces turned to
// it unless something stands between them and the moon and casts a shadow.
// Faces angled off the centreline sit a little darker so chamfered corners
// read as edges.

uniform float tone : hint_range(0.0, 1.0) = 0.35;
uniform float sky_light : hint_range(0.0, 1.0) = 0.4;
uniform float moon_light : hint_range(0.0, 1.0) = 0.6;
uniform float underside : hint_range(0.0, 1.0) = 0.35;
uniform float facet_shade : hint_range(0.0, 1.0) = 0.2;

const float DISPLAY_GAMMA = 2.2;

void fragment() {
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (!FRONT_FACING) {
		normal = -normal;
	}
	float facet = 1.0 - facet_shade * abs(normal.x);
	float sky = mix(underside, 1.0, normal.y * 0.5 + 0.5);
	ALBEDO = vec3(pow(tone * facet, DISPLAY_GAMMA));
	EMISSION = vec3(pow(tone * facet * sky_light * sky, DISPLAY_GAMMA));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float facing = max(dot(NORMAL, LIGHT), 0.0);
	DIFFUSE_LIGHT += facing * ATTENUATION * LIGHT_COLOR / PI * moon_light;
}
