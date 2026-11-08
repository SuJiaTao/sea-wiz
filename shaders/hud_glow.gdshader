shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// Head-up display: symbology is light on glass, built like a burned-in film
// date: a slightly soft core, a tight bloom and a wide faint glow, with a
// touch of grain riding on the light itself.

uniform float core_softness_pixels : hint_range(0.0, 3.0) = 0.6;
uniform float bloom_radius_pixels : hint_range(0.5, 12.0) = 2.5;
uniform float bloom_amount : hint_range(0.0, 3.0) = 0.7;
uniform float glow_radius_pixels : hint_range(1.0, 40.0) = 9.0;
uniform float glow_amount : hint_range(0.0, 3.0) = 0.45;
uniform float grain_amount : hint_range(0.0, 0.5) = 0.12;

const int RING_TAPS = 8;
const float GRAIN_TILE = 512.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec4 sharp = texture(TEXTURE, UV);
	vec4 soft = vec4(0.0);
	vec4 bloom = vec4(0.0);
	vec4 glow = vec4(0.0);
	for (int tap = 0; tap < RING_TAPS; tap++) {
		float angle = TAU * float(tap) / float(RING_TAPS);
		vec2 heading = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE;
		soft += texture(TEXTURE, UV + heading * core_softness_pixels);
		bloom += texture(TEXTURE, UV + heading * bloom_radius_pixels) + texture(TEXTURE, UV + heading * bloom_radius_pixels * 0.5);
		glow += texture(TEXTURE, UV + heading * glow_radius_pixels) + texture(TEXTURE, UV + heading * glow_radius_pixels * 0.5);
	}
	vec4 core = mix(sharp, soft / float(RING_TAPS), 0.5);
	bloom /= float(RING_TAPS * 2);
	glow /= float(RING_TAPS * 2);
	vec4 light = core + bloom * bloom_amount + glow * glow_amount;
	float grain = 1.0 + (hash12(UV / TEXTURE_PIXEL_SIZE + fract(TIME) * GRAIN_TILE) - 0.5) * 2.0 * grain_amount;
	COLOR = vec4(light.rgb * grain, clamp(light.a, 0.0, 1.0));
}
