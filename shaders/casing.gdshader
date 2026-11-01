shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float now = 0.0;
uniform float hot_level = 1.1;
uniform float cold_level = 0.16;
uniform float cooling_time = 5.0;

const float DISPLAY_GAMMA = 2.2;

varying float level;

void vertex() {
	float since_ejected = max(now - INSTANCE_CUSTOM.x, 0.0);
	level = mix(cold_level, hot_level, exp(-since_ejected / cooling_time));
}

void fragment() {
	ALBEDO = vec3(pow(level, DISPLAY_GAMMA));
}
