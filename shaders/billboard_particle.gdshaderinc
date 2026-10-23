varying float particle_progress;
varying float particle_seed;
varying float particle_level;
varying float particle_opacity;

vec3 billboard_vertex(vec3 corner, mat4 model, mat4 view, float progress, float seed) {
	float base = length(model[0].xyz);
	vec3 centre = (view * vec4(model[3].xyz, 1.0)).xyz;
	float size = particle_size(base, progress, -centre.z);
	float angle = seed * TAU;
	vec2 turned = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * corner.xy;
	return centre + vec3(turned * size, 0.0);
}
