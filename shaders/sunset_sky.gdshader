shader_type sky;

#include "res://shaders/sunset.gdshaderinc"

uniform float sun_elevation_deg = 3.0;
uniform float sun_bearing_deg = 270.0;
uniform float daylight : hint_range(0.0, 1.0) = 1.0;

void sky() {
	vec3 sun = sunset_sun_direction(sun_elevation_deg, sun_bearing_deg);
	COLOR = sunset_sky(EYEDIR, sun, daylight, TIME, true);
}
