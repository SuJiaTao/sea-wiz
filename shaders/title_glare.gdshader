shader_type canvas_item;
render_mode unshaded;

// Camera glare on the title, the same kind the game's sight draws: every
// small hard point of light (a sun glint on the water) throws a faint
// four-pointed star. Broad bright areas such as the sun's own disc are
// skipped, since only a point brighter than its surroundings flares.

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
uniform float threshold : hint_range(0.0, 1.0) = 0.85;
uniform float strength : hint_range(0.0, 6.0) = 2.5;
uniform float length_px : hint_range(2.0, 128.0) = 22.0;
uniform float rotation : hint_range(0.0, 3.1416) = 0.785;
uniform float shimmer_speed : hint_range(0.0, 10.0) = 3.0;

const int RAYS = 4;
const int STEPS = 6;
const float POINT_PX = 3.0;
const float FALLOFF = 2.6;
const float SHIMMER_DEPTH = 0.35;
const float SHIMMER_PHASE = 2.1;
const vec3 LUMA = vec3(0.299, 0.587, 0.114);

float hash12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float brightness(vec2 at) {
	return dot(texture(screen, at).rgb, LUMA);
}

// How much brighter a spot is than the pixels beside it, past the threshold.
float point_light(vec2 at, vec2 across) {
	float here = brightness(at);
	if (here <= threshold) {
		return 0.0;
	}
	float side = max(brightness(at + across), brightness(at - across));
	return max(here - max(side, threshold), 0.0) / (1.0 - threshold);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 colour = texture(screen, uv).rgb;
	vec3 flare = vec3(0.0);
	for (int ray = 0; ray < RAYS; ray++) {
		float angle = rotation + TAU * float(ray) / float(RAYS);
		vec2 heading = vec2(cos(angle), sin(angle));
		vec2 direction = heading * SCREEN_PIXEL_SIZE * length_px;
		vec2 across = vec2(-heading.y, heading.x) * SCREEN_PIXEL_SIZE * POINT_PX;
		float shimmer = 1.0 - SHIMMER_DEPTH * (0.5 + 0.5 * sin(TIME * shimmer_speed + float(ray) * SHIMMER_PHASE));
		float jitter = hash12(FRAGCOORD.xy + float(ray) * 7.7);
		for (int step = 1; step <= STEPS; step++) {
			float along = (float(step) - jitter) / float(STEPS);
			vec2 at = uv - direction * along;
			float light = point_light(at, across);
			flare += texture(screen, at).rgb * light * exp(-along * FALLOFF) * shimmer;
		}
	}
	flare *= strength / float(STEPS);
	COLOR = vec4(colour + flare, 1.0);
}
