shader_type spatial;
render_mode cull_disabled, ambient_light_disabled;

// Haze grey paint under a night sky: the open sky lights every face a little,
// more on the ones turned up, and the moonlight falls on the faces turned to
// it unless something stands between them and the moon and casts a shadow.
// Faces angled off the centreline sit a little darker so chamfered corners
// read as edges. Painted deck markings show through the paint, and
// a glow lets a part (a laser lens, a hot barrel) light up on its own. A
// perforated part (the gun's muzzle shroud) has rows of round holes cut in it.

uniform float tone : hint_range(0.0, 1.0) = 0.35;
uniform float sky_light : hint_range(0.0, 1.0) = 0.15;
uniform float moon_light : hint_range(0.0, 1.0) = 0.5;
uniform float underside : hint_range(0.0, 1.0) = 0.35;
uniform float facet_shade : hint_range(0.0, 1.0) = 0.2;
uniform float exposure : hint_range(0.0, 2.0) = 0.78;
uniform sampler2D markings : source_color, hint_default_white;
uniform float markings_base : hint_range(0.01, 1.0) = 1.0;
// White deck paint is a few times brighter than the grey around it, never so
// bright that it blooms or throws lens glints through the night vision.
uniform float markings_ceiling : hint_range(1.0, 20.0) = 2.0;
uniform vec3 glow_color : source_color = vec3(1.0);
instance uniform float glow = 0.0;
uniform vec2 perforation = vec2(0.0);
uniform float hole_radius : hint_range(0.0, 0.5) = 0.32;

const float DISPLAY_GAMMA = 2.2;

void fragment() {
	if (perforation.x > 0.0 && length(fract(UV * perforation) - 0.5) < hole_radius) {
		discard;
	}
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (!FRONT_FACING) {
		normal = -normal;
	}
	float facet = 1.0 - facet_shade * abs(normal.x);
	float sky = mix(underside, 1.0, normal.y * 0.5 + 0.5);
	float marked = min(dot(texture(markings, UV).rgb, vec3(1.0 / 3.0)) / markings_base, markings_ceiling);
	float shade = tone * facet * marked * exposure;
	ALBEDO = vec3(pow(shade, DISPLAY_GAMMA));
	EMISSION = vec3(pow(shade * sky_light * sky, DISPLAY_GAMMA)) + glow_color * glow;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float facing = max(dot(NORMAL, LIGHT), 0.0);
	DIFFUSE_LIGHT += facing * ATTENUATION * LIGHT_COLOR / PI * moon_light;
}
