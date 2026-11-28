shader_type sky;
// Sky for the little planet: on a ball, the horizon is BELOW eye level, and more so the
// higher the camera. This sky lowers its horizon by exactly that angle, so it meets the
// edge of the planet instead of leaving a grey band above it. Flat world (planet_radius = 0):
// a normal sky with the horizon at eye level.
//
// Use: WorldEnvironment > Environment > Background: Sky > Sky > Sky Material:
//      New ShaderMaterial with this shader.

uniform vec4 top_color : source_color = vec4(0.29, 0.53, 0.85, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.73, 0.84, 0.93, 1.0);
// Below the horizon (seen past the edge of the planet). Same as the horizon = seamless haze;
// darker = the planet floats in space.
uniform vec4 below_color : source_color = vec4(0.73, 0.84, 0.93, 1.0);
uniform float sky_curve : hint_range(0.01, 1.0) = 0.25;      // how fast it blends to top_color
uniform float below_curve : hint_range(0.01, 1.0) = 0.15;
uniform float energy = 1.0;

// Sun disc (follows the first DirectionalLight3D)
uniform float sun_size_deg = 2.5;
uniform float sun_glow = 0.35;

global uniform vec3 wrap_center;
global uniform float planet_radius;
uniform float ground_y = 0.0;


void sky() {
	// Horizon dip: the angle between eye level and the planet's edge
	float dip = 0.0;
	if (planet_radius > 0.0) {
		float h = max(POSITION.y - ground_y, 0.01);
		dip = acos(clamp(planet_radius / (planet_radius + h), -1.0, 1.0));
	}

	// Elevation of this direction above the (lowered) horizon, in 0..1 per hemisphere
	float elev = (asin(clamp(EYEDIR.y, -1.0, 1.0)) + dip) / (PI * 0.5);

	vec3 col;
	if (elev >= 0.0) {
		col = mix(horizon_color.rgb, top_color.rgb, pow(clamp(elev, 0.0, 1.0), sky_curve));
	} else {
		col = mix(horizon_color.rgb, below_color.rgb, pow(clamp(-elev, 0.0, 1.0), below_curve));
	}

	// Sun
	if (LIGHT0_ENABLED) {
		float c = dot(EYEDIR, LIGHT0_DIRECTION);
		float r = cos(radians(sun_size_deg));
		float disc = smoothstep(r, mix(r, 1.0, 0.3), c);
		float glow = pow(max(c, 0.0), 64.0) * sun_glow;
		col += LIGHT0_COLOR * LIGHT0_ENERGY * (disc + glow);
	}

	COLOR = col * energy;
}