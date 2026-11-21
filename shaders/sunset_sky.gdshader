shader_type sky;

#include "res://shaders/sunset.gdshaderinc"

uniform float glow_bearing_deg = 93.0;
uniform float dusk : hint_range(0.0, 1.0) = 0.0;
uniform vec2 view_heading = vec2(0.0, -1.0);
uniform float horizon_drop = 0.0;

void sky() {
	COLOR = sunset_sky(EYEDIR, sunset_glow_direction(glow_bearing_deg), dusk, view_heading, horizon_drop, TIME);
}
