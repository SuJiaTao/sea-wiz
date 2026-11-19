shader_type spatial;
render_mode unshaded, shadows_disabled;

// The thrown moon: grey highlands, dark seas and craters, and as it is shot
// a web of white-hot cracks spreads across it.

uniform vec3 highland : source_color = vec3(0.22);
uniform vec3 seas : source_color = vec3(0.1);
uniform vec3 crack_heat : source_color = vec3(2.2);
uniform float maria_scale = 2.2;
uniform float crater_scale = 9.0;
uniform float crack_scale = 4.0;
uniform float crack_width = 0.012;

instance uniform float cracks = 0.0;

varying vec3 sphere;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), u.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), u.x), u.y);
	float b = mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), u.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), u.x), u.y);
	return mix(a, b, u.z);
}

float fbm3(vec3 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		total += noise3(p) * amplitude;
		p *= 2.03;
		amplitude *= 0.5;
	}
	return total;
}

void vertex() {
	sphere = normalize(VERTEX);
}

void fragment() {
	float maria = smoothstep(0.45, 0.6, fbm3(sphere * maria_scale));
	float craters = smoothstep(0.62, 0.7, noise3(sphere * crater_scale)) * 0.25;
	vec3 ground = mix(highland, seas, maria) * (1.0 - craters);
	float web = abs(fbm3(sphere * crack_scale + 11.0) - 0.5);
	float reach = smoothstep(1.0 - cracks, 1.0, fbm3(sphere * 1.3 + 3.0) + 0.3);
	float crack = (1.0 - smoothstep(0.0, crack_width, web)) * reach * step(0.001, cracks);
	ALBEDO = mix(ground, crack_heat, crack);
}
