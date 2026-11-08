shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// Head-up display: the symbology is light projected onto glass, so every
// line and letter carries a soft halo around a crisp core.

uniform float glow_amount : hint_range(0.0, 4.0) = 1.3;
uniform float glow_radius_pixels : hint_range(0.5, 12.0) = 3.5;
uniform float core_gain : hint_range(0.5, 2.0) = 1.15;

const int GLOW_RINGS = 3;
const int GLOW_TAPS = 8;

void fragment() {
	vec4 core = texture(TEXTURE, UV);
	vec4 halo = vec4(0.0);
	float weight = 0.0;
	for (int ring = 1; ring <= GLOW_RINGS; ring++) {
		float reach = glow_radius_pixels * float(ring) / float(GLOW_RINGS);
		float falloff = 1.0 / float(ring);
		for (int tap = 0; tap < GLOW_TAPS; tap++) {
			float angle = TAU * (float(tap) + 0.5 * float(ring)) / float(GLOW_TAPS);
			halo += texture(TEXTURE, UV + vec2(cos(angle), sin(angle)) * reach * TEXTURE_PIXEL_SIZE) * falloff;
			weight += falloff;
		}
	}
	halo /= weight;
	vec3 light = core.rgb * core_gain + halo.rgb * glow_amount;
	COLOR = vec4(light, clamp(core.a + halo.a * glow_amount, 0.0, 1.0));
}
