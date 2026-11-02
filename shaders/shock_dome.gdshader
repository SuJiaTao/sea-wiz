shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;

// The white condensation shell that flashes out around a big blast: bright
// at its rim, thin in the middle, breaking up and fading as it goes.

uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform float brightness : hint_range(0.0, 1.0) = 0.6;
uniform float rim_power = 3.0;
uniform float breakup_scale = 6.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(0.0, 1.0, fract(p));
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float breakup = smoothstep(fade, fade + 0.3, value_noise(UV * breakup_scale * vec2(2.0, 1.0)));
	ALBEDO = vec3(pow(brightness, 2.2));
	ALPHA = clamp((0.06 + rim * 0.8) * breakup * (1.0 - fade), 0.0, 1.0);
}
