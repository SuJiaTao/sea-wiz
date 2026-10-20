shader_type canvas_item;
render_mode unshaded;

// Post-process applied to the low-resolution SubViewport.
// Turns the rendered scene into a coarse thermal / IR sensor image:
// luminance -> gain -> posterise -> sensor noise, scanlines, vignette.

uniform float gain : hint_range(0.2, 4.0) = 1.35;
uniform float black_level : hint_range(0.0, 0.5) = 0.02;
uniform float levels : hint_range(2.0, 32.0) = 7.0;
uniform float polarity : hint_range(0.0, 1.0) = 0.0; // 0 = white hot, 1 = black hot
uniform float noise_amount : hint_range(0.0, 0.5) = 0.038;
uniform float fixed_pattern : hint_range(0.0, 0.3) = 0.022;
uniform float scanline_amount : hint_range(0.0, 1.0) = 0.16;
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.40;
uniform float sweep_amount : hint_range(0.0, 0.5) = 0.05;
uniform float sweep_speed = 0.35;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 0.985);
uniform float shake_x = 0.0;
uniform float shake_y = 0.0;
uniform float bloom_amount : hint_range(0.0, 2.0) = 0.85;
uniform float bloom_floor : hint_range(0.0, 1.0) = 0.42;
uniform vec2 sensor_size = vec2(320.0, 180.0);
// Whiteout, 0..1: the sensor saturating on a huge heat event.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(233.34, 851.73));
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
}

float luma(vec3 c) {
	return dot(c, vec3(0.30, 0.59, 0.11));
}

void fragment() {
	vec2 uv = UV + vec2(shake_x, shake_y);
	uv = clamp(uv, vec2(0.0), vec2(1.0));

	// Base sample plus a cheap 4-tap blur used as a poor-man's IR bloom so hot
	// bodies smear the way they do on a real sensor.
	vec3 base = texture(TEXTURE, uv).rgb;
	vec2 tx = 1.0 / sensor_size;
	vec3 blur = texture(TEXTURE, uv + vec2(tx.x, 0.0)).rgb;
	blur += texture(TEXTURE, uv - vec2(tx.x, 0.0)).rgb;
	blur += texture(TEXTURE, uv + vec2(0.0, tx.y)).rgb;
	blur += texture(TEXTURE, uv - vec2(0.0, tx.y)).rgb;
	blur *= 0.25;

	// Only genuinely hot pixels are allowed to smear into their neighbours;
	// letting the whole image bloom just lifts the sea into a grey fog.
	float l = luma(base) + max(luma(blur) - bloom_floor, 0.0) * bloom_amount;
	l = max(l - black_level, 0.0) * gain;
	l = clamp(l + flash, 0.0, 1.0);

	// Sensor noise: per-frame shimmer plus a static per-pixel offset (FPN).
	vec2 px = floor(uv * sensor_size);
	float shimmer = hash21(px + fract(TIME) * 91.7) - 0.5;
	float fpn = hash21(px * 1.37) - 0.5;
	l += shimmer * noise_amount + fpn * fixed_pattern;

	// Slow horizontal integration sweep.
	float sweep = sin((uv.y * 3.0 - TIME * sweep_speed) * 6.2831);
	l += sweep * sweep_amount * 0.25;

	l = clamp(l, 0.0, 1.0);

	// Posterise to a coarse grey ramp.
	float q = floor(l * levels) / max(levels - 1.0, 1.0);
	q = clamp(q, 0.0, 1.0);

	// White hot / black hot.
	q = mix(q, 1.0 - q, polarity);

	// Interlace scanlines.
	float scan = 1.0 - scanline_amount * step(0.5, fract(uv.y * sensor_size.y * 0.5));
	q *= scan;

	// Vignette.
	vec2 d = uv - vec2(0.5);
	float vig = 1.0 - vignette_amount * dot(d, d) * 2.4;
	q *= clamp(vig, 0.0, 1.0);

	COLOR = vec4(tint * q, 1.0);
}
