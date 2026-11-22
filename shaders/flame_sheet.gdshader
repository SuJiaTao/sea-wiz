shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

// One fire on a card that turns about the vertical to face the camera. It moves like the Doom fire: heat is fed in along a
// wandering bed at the root and climbs in tall packets, each column losing
// heat at its own random rate and being pushed sideways by gusts, so the top
// tears into flickering tongues. Unlike Doom the packets are smooth, not
// blocky. It is seen the way a night sight sees it: the body is so bright it
// burns out to a flat glare with detail only at its edges, and a soft halo
// spreads into the dark around it.

uniform sampler2D palette : source_color, filter_linear, repeat_disable;
uniform float intensity = 1.0;
uniform float rise_speed = 1.6;
uniform float gust_speed = 0.5;

instance uniform float strength = 1.0;
instance uniform float column = 0.0;

const float SEED_SPREAD = 37.0;
const int OCTAVES = 3;
// Heat packets are narrow and tall, like Doom's columns, then softened.
const vec2 PACKET_SCALE = vec2(14.0, 1.8);
// The bed of fuel along the root, and how fast its hot spots wander.
const float BED_WIDTH = 0.46;
const float BED_SCALE = 3.0;
const float BED_SPEED = 0.35;
const float ROOT_HEAT = 1.25;
// Heat lost per unit of height, and how unevenly the columns lose it.
const float COOLING = 1.15;
const float COOLING_SPREAD = 2.6;
// The sideways push: a gust over the whole flame, and each column's wander.
const float GUST = 0.28;
const float WANDER = 0.12;
// The night sight burns the body out: how quickly heat reaches full glare.
const float GLARE_GAIN = 1.7;
// Glow spread into the air past the flame's edge, as a share of heat below zero.
const float HALO_REACH = 0.22;
const float HALO_HEAT = 0.32;
const float HALO_ALPHA = 0.5;
// The flame fades out before the top of its sheet.
const float TOP_FADE = 0.82;
// The whole flame flutters in brightness, fast, as a night sight shows it.
const float FLUTTER = 0.08;
const float FLUTTER_SPEED = 11.0;
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
	float h = 1.0 - UV.y;
	float x = UV.x - 0.5;
	vec2 seed = vec2(column * SEED_SPREAD, column * SEED_SPREAD * 0.5);
	float climb = TIME * rise_speed;

	// Gusts lean the flame; each column also wanders, more the higher it has climbed.
	float gust = (value_noise(vec2(seed.x, TIME * gust_speed)) - 0.5) * GUST;
	float wander = (value_noise(vec2(x * PACKET_SCALE.x * 0.5, h * PACKET_SCALE.y - climb) + seed + 3.7) - 0.5) * WANDER;
	x -= (gust * h + wander) * h;

	// Fuel feeds the root unevenly, in hot spots that wander along it.
	float spots = value_noise(vec2(x * BED_SCALE, TIME * BED_SPEED) + seed);
	float bed = smoothstep(BED_WIDTH, 0.0, abs(x)) * mix(0.75, 1.15, spots);

	// Packets climb; each one cools at its own rate on the way up.
	float packet = fbm(vec2(x * PACKET_SCALE.x, h * PACKET_SCALE.y - climb) + seed);
	float cooling = h * (COOLING + COOLING_SPREAD * (0.5 - packet) * 2.0);
	float heat = bed * ROOT_HEAT - max(cooling, 0.0) - h * h * COOLING * 0.5;
	heat = (heat - (1.0 - strength)) / max(strength, MIN_STRENGTH);
	heat *= 1.0 + FLUTTER * (value_noise(vec2(seed.y, TIME * FLUTTER_SPEED)) - 0.5) * 2.0;

	float body = 1.0 - exp(-max(heat, 0.0) * GLARE_GAIN);
	float halo = exp(min(heat, 0.0) / HALO_REACH) * smoothstep(1.0, 0.0, h) * strength;
	float top = smoothstep(1.0, TOP_FADE, h);

	float alpha = max(body, halo * HALO_ALPHA) * top;
	if (alpha <= 0.003) {
		discard;
	}
	float shade = max(body, halo * HALO_HEAT);
	vec4 colour = texture(palette, vec2(clamp(shade, 0.0, 1.0), 0.5));
	ALBEDO = colour.rgb * intensity;
	ALPHA = alpha;
}
