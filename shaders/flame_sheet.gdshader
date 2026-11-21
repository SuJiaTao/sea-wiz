shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

// One flame, always turned to face the camera so it never shows an edge or
// a cross. It is drawn as a solid shape, not wisps: a round, heavy base
// that narrows into one or two licking tongues, with a clean edge. Inside
// it is hottest low down and toward the middle, almost white, cooling to
// the rim; outside it a soft glow spreads into the air around it. Slow,
// large lobes of noise climb the shape so the tongues lick, split and
// rejoin, and the whole flame sways a little.

uniform sampler2D palette : source_color, filter_linear, repeat_disable;
uniform float intensity = 1.0;
uniform float rise_speed = 1.4;
uniform float sway_speed = 0.8;

instance uniform float strength = 1.0;
instance uniform float column = 0.0;

const float SEED_SPREAD = 37.0;
const int OCTAVES = 2;
// Where the body sits inside the card, leaving a margin for the glow.
const float BODY_HALF_WIDTH = 0.56;
const float BODY_TOP = 0.86;
// Shape of the body up its height: round at the base, pointed at the tip.
const float BASE_ROUNDNESS = 0.22;
const float TIP_TAPER = 0.6;
const float PROFILE_PEAK = 0.62;
// How far the climbing lobes bend and bite into the shape, and how big they are.
const float LICK_BEND = 0.85;
const float LICK_SCALE = 1.6;
const float TONGUE_BITE = 1.6;
const float TONGUE_SCALE = 2.2;
const float TONGUE_STRETCH = 0.45;
const float SWAY = 0.22;
// Width of the edge, so it is crisp but not aliased.
const float EDGE = 0.06;
// The core: how deep into the body it starts, and how far up it reaches.
const float CORE_DEPTH = 0.3;
const float CORE_REACH = 0.7;
// The hottest part sits a little above the base, not right on it.
const float CORE_LIFT = 0.15;
const float BODY_HEAT = 0.3;
const float CORE_HEAT = 0.7;
const float GLOW_HEAT = 0.3;
const float GLOW_REACH = 0.22;
const float GLOW_ALPHA = 0.55;
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
		p *= 2.03;
		amplitude *= 0.5;
	}
	return total;
}

void vertex() {
	// Turn about the vertical to face the camera, keeping the card upright.
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 to_camera = CAMERA_POSITION_WORLD - centre;
	to_camera.y = 0.0;
	to_camera = length(to_camera) > 0.0001 ? normalize(to_camera) : vec3(0.0, 0.0, 1.0);
	vec3 across = normalize(cross(vec3(0.0, 1.0, 0.0), to_camera));
	float width = length(MODEL_MATRIX[0].xyz);
	float height = length(MODEL_MATRIX[1].xyz);
	vec3 world = centre + across * VERTEX.x * width + vec3(0.0, 1.0, 0.0) * VERTEX.y * height;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = (VIEW_MATRIX * vec4(to_camera, 0.0)).xyz;
}

void fragment() {
	float grown = max(strength, MIN_STRENGTH);
	vec2 seed = vec2(column * SEED_SPREAD, column * SEED_SPREAD * 0.5);
	float x = (UV.x - 0.5) * 2.0;
	float up = (1.0 - UV.y) / (BODY_TOP * mix(0.6, 1.0, grown));

	// Climbing lobes bend the flame side to side, more the higher up.
	float lick = fbm(vec2(x * LICK_SCALE, up * LICK_SCALE - TIME * rise_speed) + seed) - 0.5;
	float sway = (value_noise(vec2(column * SEED_SPREAD, TIME * sway_speed)) - 0.5) * SWAY;
	x -= (lick * LICK_BEND + sway) * up;

	float h = clamp(up, 0.0, 1.0);
	float profile = pow(h, BASE_ROUNDNESS) * pow(1.0 - h, TIP_TAPER) / PROFILE_PEAK;
	// Tongues are tall lobes, so the top splits into licks rather than bumps.
	float tongues = fbm(vec2(x * TONGUE_SCALE, up * TONGUE_SCALE * TONGUE_STRETCH - TIME * rise_speed * 1.3) + seed + 11.0) - 0.5;
	float inside = profile * BODY_HALF_WIDTH * mix(0.7, 1.0, grown) - abs(x) + tongues * TONGUE_BITE * pow(h, 1.4);
	inside = up > 1.0 ? -abs(up - 1.0) - abs(x) : inside;

	float body = smoothstep(0.0, EDGE, inside);
	float core = smoothstep(EDGE, CORE_DEPTH, inside) * smoothstep(0.0, CORE_LIFT, h) * (1.0 - smoothstep(CORE_LIFT, CORE_REACH, h));
	float glow = exp(-max(-inside, 0.0) / GLOW_REACH) * (1.0 - h) * (1.0 - body) * grown;

	float heat = body * (BODY_HEAT + CORE_HEAT * core) + glow * GLOW_HEAT;
	float alpha = max(body, glow * GLOW_ALPHA);
	if (alpha <= 0.002) {
		discard;
	}
	vec4 colour = texture(palette, vec2(clamp(heat, 0.0, 1.0), 0.5));
	ALBEDO = colour.rgb * intensity;
	ALPHA = alpha;
}
