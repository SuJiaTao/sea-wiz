shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// One sheet of a fire. A few sheets cross at the flame's centre, so it has
// depth from every side. Rolling noise climbs each sheet; the flame is
// widest and hottest at its root, tears into licking tongues as it rises,
// and turns to dark smoke at the tips. Sheets seen edge-on fade away.

uniform sampler2D palette : source_color, filter_linear, repeat_disable;
uniform float intensity = 1.0;
uniform float rise_speed = 1.3;
uniform float churn_speed = 0.6;
uniform float tongue_scale = 3.2;
uniform float warp = 0.55;
uniform float edge_fade : hint_range(0.0, 1.0) = 0.35;

instance uniform float strength = 1.0;
instance uniform float column = 0.0;

const float SEED_SPREAD = 37.0;
const float OCTAVE_GAIN = 0.5;
const float OCTAVE_LACUNARITY = 2.03;
const int OCTAVES = 4;
const float ROOT_HEAT = 1.3;
const float NOISE_REACH = 1.35;
const float TOP_COOLING = 0.9;
const float TAPER = 0.4;
const float WIDTH = 1.0;
const float SWAY = 0.6;
const float NOISE_BITE = 1.6;
const float MIN_STRENGTH = 0.001;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < OCTAVES; octave++) {
		total += value_noise(p) * amplitude;
		p *= OCTAVE_LACUNARITY;
		amplitude *= OCTAVE_GAIN;
	}
	return total;
}

void fragment() {
	float height = 1.0 - UV.y;
	float across = abs(UV.x - 0.5) * 2.0;
	vec2 seed = vec2(column * SEED_SPREAD, column * SEED_SPREAD * 0.5);
	vec2 p = vec2(UV.x * tongue_scale, height * tongue_scale * 0.5 - TIME * rise_speed) + seed;
	vec2 churn = vec2(fbm(p * 0.8 + TIME * churn_speed), fbm(p * 0.8 - TIME * churn_speed + 5.2)) - 0.5;
	float flicker = fbm(p + churn * warp * 2.0) - 0.5;
	across = abs(UV.x - 0.5 + churn.x * SWAY * height) * 2.0;
	float width = WIDTH * pow(max(1.0 - height, 0.0), TAPER);
	float body = clamp(1.0 - across / max(width, 0.02), 0.0, 1.0);
	float reach = clamp(1.0 - across / max(width * NOISE_REACH, 0.02), 0.0, 1.0);
	float heat = body * (ROOT_HEAT - height * TOP_COOLING) + flicker * NOISE_BITE * (0.35 + height) * reach;
	heat *= smoothstep(1.0, 0.8, height) * reach;
	heat = (heat - (1.0 - strength)) / max(strength, MIN_STRENGTH);
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = smoothstep(0.0, edge_fade, facing);
	if (heat <= 0.0 || edge <= 0.0) {
		discard;
	}
	vec4 colour = texture(palette, vec2(clamp(heat, 0.0, 1.0), 0.5));
	ALBEDO = colour.rgb * intensity;
	ALPHA = colour.a * edge;
}
