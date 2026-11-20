// Where the ship's moon shadow falls. The ship's outline as seen from the moon
// is baked into a map once, so any point can be tested cheaply: points along
// the same moonbeam share the same spot on the map.

uniform sampler2D moon_shadow_map : hint_default_transparent, filter_linear, repeat_disable;
uniform vec3 moon_shadow_origin = vec3(0.0);
uniform vec3 moon_shadow_right = vec3(1.0, 0.0, 0.0);
uniform vec3 moon_shadow_up = vec3(0.0, 0.0, -1.0);
uniform float moon_shadow_extent = 0.0;

float moon_light_at(vec3 world, float darkest) {
	if (moon_shadow_extent <= 0.0) {
		return 1.0;
	}
	vec3 offset = world - moon_shadow_origin;
	vec2 uv = vec2(dot(offset, moon_shadow_right), -dot(offset, moon_shadow_up)) / moon_shadow_extent + 0.5;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 1.0;
	}
	return mix(1.0, darkest, texture(moon_shadow_map, uv).a);
}
