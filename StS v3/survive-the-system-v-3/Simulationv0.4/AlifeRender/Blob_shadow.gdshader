shader_type spatial;
// Multiply blend: order-independent, so overlapping shadows never need sorting
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled, shadows_disabled;

// Same agent_data texture as the sprite shader (test3d.gdshader)
uniform sampler2D agent_data : filter_nearest, repeat_disable;
uniform int tex_width = 1024;
uniform float world_height = 48.0;

uniform float ground_y = 0.0;                          // height of the ground
uniform vec2 sun_offset = vec2(0.3, 0.2);              // shadow shift (x, z) per unit of height
uniform float strength : hint_range(0.0, 1.0) = 0.45;  // darkness at the center
uniform float radius_scale = 0.5;                      // shadow radius relative to agent size
uniform float fade_height = 10.0;                      // no shadow above this height
uniform float softness : hint_range(0.0, 1.0) = 0.7;   // 0 = hard edge, 1 = fades from the center
uniform float lift = 0.0;                              // disk height above the ground: anything
                                                       // lower than this (moss, grass) gets darkened

// Photo-range shadow (trees): the radius is the area the agent shades in the simulation,
// (photo range + 0.5) sun-grid cells, instead of its size. The photo range comes in the
// ACTION bits (4 bits, 0..15): the species writes current_action[i] = its photo range.
uniform bool use_photo_range = false;
uniform float sun_cell_size = 1.0;                     // world units per sun-grid cell
uniform int min_range = 1;                             // smaller range: no shadow (fruits)

// Wrap view + little planet (same as the sprite shader)
uniform vec3 world_size = vec3(100.0);
uniform vec3 wrap_axes = vec3(0.0);
global uniform vec3 wrap_center;
global uniform float planet_radius;

varying float v_strength;


vec3 nearest_image(vec3 p, vec3 ref) {
	vec3 d = p - ref;
	d -= wrap_axes * world_size * round(d / max(world_size, vec3(1e-6)));
	return ref + d;
}

// Little planet (same as the sprite shader): sphere touching the ground at wrap_center
vec3 curve(vec3 p, out vec3 up) {
	up = vec3(0.0, 1.0, 0.0);
	if (planet_radius <= 0.0) return p;
	vec2 d = p.xz - wrap_center.xz;
	float dist = length(d);
	if (dist < 1e-5) return p;
	float a = dist / planet_radius;
	vec2 dir = d / dist;
	up = vec3(dir.x * sin(a), cos(a), dir.y * sin(a));
	return vec3(wrap_center.x, -planet_radius, wrap_center.z) + up * (planet_radius + p.y);
}

float planet_limit() {
	return min(min(world_size.x, world_size.z) * 0.5, PI * planet_radius * 0.97);
}


void vertex() {
	ivec2 px = ivec2(INSTANCE_ID % tex_width, INSTANCE_ID / tex_width);
	vec4 d = texelFetch(agent_data, px, 0);

	int v = int(d.w + 0.5);
	int state = v & 3;
	float size = float((v >> 6) & 255) * 0.1;         // MUST match the sprite shader's size decoding
	int photo_range = (v >> 2) & 15;                   // the action bits (photo-range shadows)

	int b = int(d.z + 0.5);
	float y = float(b >> 12) / 4095.0 * world_height;

	bool too_small = use_photo_range && photo_range < min_range;
	if (state == 0 || too_small) {
		VERTEX = vec3(0.0);                            // free slot / no shade: not drawn
		v_strength = 0.0;
	} else {
		float h = max(y - ground_y, 0.0);
		v_strength = clamp(1.0 - h / fade_height, 0.0, 1.0);
		vec2 c = vec2(d.x, d.y) + sun_offset * h;      // shift with the sun direction

		vec3 flat_spot = nearest_image(MODEL_MATRIX[3].xyz + vec3(c.x, ground_y + 0.01 + lift, c.y), wrap_center);
		vec3 n;
		vec3 spot = curve(flat_spot, n);
		if (planet_radius > 0.0 && distance(flat_spot.xz, wrap_center.xz) > planet_limit()) {
			v_strength = 0.0;                          // outside the planet's circle
		}

		// Lay the quad on the ground's surface (tangent plane), x and z along it
		vec3 tx = normalize(cross(n, vec3(0.0, 0.0, 1.0)));
		vec3 tz = cross(tx, n);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
				vec4(tx, 0.0),
				vec4(tz, 0.0),
				vec4(n, 0.0),
				vec4(spot, 1.0));
		float radius = use_photo_range
				? (float(photo_range) + 0.5) * sun_cell_size     // the shaded area
				: size * radius_scale;                           // from the agent's size
		VERTEX *= radius * 2.0;
	}
}


void fragment() {
	float r = length(UV - 0.5) * 2.0;                  // 0 at the center, 1 at the edge
	float a = (1.0 - smoothstep(1.0 - max(softness, 0.01), 1.0, r)) * strength * v_strength;
	ALBEDO = vec3(1.0 - a);                            // multiplied with what's behind
}