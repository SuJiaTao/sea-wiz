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
uniform float grain_amount : hint_range(0.0, 0.5) = 0.25;
// Damage to the display: colour channels pull apart and bands of lines tear sideways.
uniform float corruption : hint_range(0.0, 1.0) = 0.0;
uniform float split_pixels : hint_range(0.0, 20.0) = 7.0;
uniform float tear_pixels : hint_range(0.0, 80.0) = 36.0;

const int RING_TAPS = 6;
const float GRAIN_TILE = 512.0;
const float TEAR_BANDS = 48.0;
const float TEAR_RATE = 14.0;
const float TEAR_SHARE = 0.35;
const float SPLIT_WOBBLE = 3.0;
const float TEAR_SEED = 5.3;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 torn_uv(vec2 uv, vec2 pixel) {
	float band = floor(uv.y * TEAR_BANDS);
	float frame = floor(TIME * TEAR_RATE);
	float roll = hash12(vec2(band, frame));
	float torn = step(1.0 - corruption * TEAR_SHARE, roll);
	float shift = (hash12(vec2(band + TEAR_SEED, frame)) - 0.5) * 2.0 * tear_pixels * corruption * torn;
	return uv + vec2(shift * pixel.x, 0.0);
}

void fragment() {
	vec2 uv = torn_uv(UV, TEXTURE_PIXEL_SIZE);
	vec4 sharp = texture(TEXTURE, uv);
	vec4 soft = vec4(0.0);
	vec4 bloom = vec4(0.0);
	vec4 glow = vec4(0.0);
	for (int tap = 0; tap < RING_TAPS; tap++) {
		float angle = TAU * float(tap) / float(RING_TAPS);
		vec2 heading = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE;
		soft += texture(TEXTURE, uv + heading * core_softness_pixels);
		bloom += texture(TEXTURE, uv + heading * bloom_radius_pixels) + texture(TEXTURE, uv + heading * bloom_radius_pixels * 0.5);
		glow += texture(TEXTURE, uv + heading * glow_radius_pixels) + texture(TEXTURE, uv + heading * glow_radius_pixels * 0.5);
	}
	vec4 core = mix(sharp, soft / float(RING_TAPS), 0.5);
	bloom /= float(RING_TAPS * 2);
	glow /= float(RING_TAPS * 2);
	vec4 light = core + bloom * bloom_amount + glow * glow_amount;
	if (corruption > 0.0) {
		float wobble = 1.0 + sin(TIME * SPLIT_WOBBLE) * 0.5;
		vec2 split = vec2(split_pixels * corruption * wobble * TEXTURE_PIXEL_SIZE.x, 0.0);
		vec4 red = texture(TEXTURE, uv + split);
		vec4 blue = texture(TEXTURE, uv - split);
		light.r = mix(light.r, red.r + bloom.r * bloom_amount, corruption);
		light.b = mix(light.b, blue.b + bloom.b * bloom_amount, corruption);
		light.g *= 1.0 - corruption * 0.4;
		light.a = max(light.a, max(red.a, blue.a) * corruption);
	}
	float grain = 1.0 + (hash12(UV / TEXTURE_PIXEL_SIZE + fract(TIME) * GRAIN_TILE) - 0.5) * 2.0 * grain_amount;
	COLOR = vec4(light.rgb * grain, clamp(light.a, 0.0, 1.0));
}
