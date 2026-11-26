shader_type spatial;
// Invisible shadow caster (the instance is SHADOWS_ONLY: never drawn, only seen by the sun).
// One flattened sphere per agent at canopy height; noise holes let light through the leaves.
render_mode unshaded, cull_disabled;

// Same agent_data texture as the sprite shader
uniform sampler2D agent_data : filter_nearest, repeat_disable;
uniform int tex_width = 1024;
uniform float world_height = 48.0;

// Size: photo range (trees, from the action bits) or the agent's size
uniform bool use_photo_range = false;
uniform float sun_cell_size = 1.0;              // world units per sun-grid cell
uniform float range_extra = 0.5;                // radius = (photo range + this) x sun cell
uniform int min_range = 1;                      // smaller range: no shadow (fruits, seedlings)
uniform float radius_scale = 0.5;               // without photo range: radius = size x this
uniform bool show_dead = true;                  // dead / decomposing agents still cast their shadow

// Shape and height (sprite_height is set by the renderer: the sprite's height at size 1)
uniform float sprite_height = 1.0;
uniform bool height_with_size = true;           // the sprite grows with size, so does the canopy
uniform float canopy_at : hint_range(0.0, 1.5) = 0.75;   // canopy center, fraction of the sprite height
uniform float flatten : hint_range(0.05, 1.0) = 0.35;    // canopy thickness relative to its width

// Leaves: noise holes (0 = solid shadow)
uniform float light_gaps : hint_range(0.0, 1.0) = 0.35;  // how much light gets through
uniform float leaf_scale = 1.5;                 // noise frequency (higher = smaller leaf patches)
uniform float ragged_edge : hint_range(0.0, 1.0) = 0.4;  // more holes toward the border
uniform float sway_speed = 0.15;                // leaves drifting in the wind (0 = still)
uniform vec2 sway_direction = vec2(1.0, 0.3);

// Wrap view + little planet (same as the sprite shader)
uniform vec3 world_size = vec3(100.0);
uniform vec3 wrap_axes = vec3(0.0);
global uniform vec3 wrap_center;
global uniform float planet_radius;

varying vec3 v_pos;     // world position (flat world), for the noise
varying float v_r;      // 0 at the canopy center, 1 at its border


vec3 nearest_image(vec3 p, vec3 ref) {
	vec3 d = p - ref;
	d -= wrap_axes * world_size * round(d / max(world_size, vec3(1e-6)));
	return ref + d;
}

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

// 3D value noise + 2 octaves
float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i + vec3(0.0, 0.0, 0.0)), hash3(i + vec3(1.0, 0.0, 0.0)), f.x),
	               mix(hash3(i + vec3(0.0, 1.0, 0.0)), hash3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
	           mix(mix(hash3(i + vec3(0.0, 0.0, 1.0)), hash3(i + vec3(1.0, 0.0, 1.0)), f.x),
	               mix(hash3(i + vec3(0.0, 1.0, 1.0)), hash3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}
float leaves(vec3 p) {
	return 0.65 * vnoise(p) + 0.35 * vnoise(p * 2.3 + 7.1);
}


void vertex() {
	ivec2 px = ivec2(INSTANCE_ID % tex_width, INSTANCE_ID / tex_width);
	vec4 d = texelFetch(agent_data, px, 0);

	int v = int(d.w + 0.5);
	int state = v & 3;
	int photo_range = (v >> 2) & 15;
	float size = float((v >> 6) & 255) * 0.1;
	int b = int(d.z + 0.5);
	float y = float(b >> 12) / 4095.0 * world_height;

	float radius = use_photo_range
			? (float(photo_range) + range_extra) * sun_cell_size
			: size * radius_scale;
	float h = sprite_height * (height_with_size ? size : 1.0) * canopy_at;

	vec3 flat_c = nearest_image(MODEL_MATRIX[3].xyz + vec3(d.x, y + h, d.y), wrap_center);
	bool past_horizon = planet_radius > 0.0
			&& distance(flat_c.xz, wrap_center.xz) > planet_limit();
	bool too_small = use_photo_range && photo_range < min_range;

	v_r = length(VERTEX) * 2.0;                       // unit sphere mesh: radius 0.5
	bool shown = state == 1 || (show_dead && state >= 2);
	if (!shown || too_small || past_horizon) {
		VERTEX = vec3(0.0);                           // free (or dead if show_dead off), or no shade
		v_pos = vec3(0.0);
	} else {
		vec3 local = VERTEX * 2.0 * vec3(radius, radius * flatten, radius);
		v_pos = flat_c + local;

		vec3 n;
		vec3 c = curve(flat_c, n);
		vec3 tx = normalize(cross(n, vec3(0.0, 0.0, 1.0)));
		vec3 tz = cross(tx, n);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
				vec4(tx, 0.0),
				vec4(n, 0.0),
				vec4(tz, 0.0),
				vec4(c, 1.0));
		VERTEX = local;
	}
}


void fragment() {
	if (light_gaps > 0.0) {
		vec3 drift = vec3(sway_direction.x, 0.0, sway_direction.y) * TIME * sway_speed;
		float n = leaves(v_pos * leaf_scale + drift);
		float gap = light_gaps + ragged_edge * smoothstep(0.55, 1.0, v_r);
		if (n < gap) {
			discard;                                  // light passes through here
		}
	}
	ALBEDO = vec3(0.0);
}