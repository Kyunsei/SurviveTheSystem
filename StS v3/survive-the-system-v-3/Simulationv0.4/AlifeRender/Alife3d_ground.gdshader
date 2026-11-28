shader_type spatial;
render_mode cull_disabled, depth_draw_never, blend_mix, ambient_light_disabled, specular_disabled;
// Lit only to receive the sun's shadow (see light()): looks unshaded in the sun.

// ---------------------------------------------------------------------------
// Ground sprite: a flat textured quad lying on the ground under each agent
// (roots, a patch of moss, a nest...). Never a billboard: it lies on the surface,
// fixed in the world, and follows the wrap view and the little planet like the sprites.
//
// Reads the same agent_data texture as the sprite shader:
//   R = x, G = z, B = y | color, A = state | action | size | life cycle
// Needs the same Shader Globals: wrap_center (vec3), planet_radius (float).
// The mesh is a 1 x 1 QuadMesh (centered); this shader lays it flat.
// ---------------------------------------------------------------------------

uniform sampler2D ground_texture : source_color, filter_nearest, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool receive_shadow = true;
uniform vec4 shade_color : source_color = vec4(0.45, 0.48, 0.62, 1.0);   // colour in full shadow

uniform float ground_scale = 1.0;               // width in world units (x the agent's size, see below)
uniform bool ground_scales_with_size = true;    // true: grows with the agent
uniform bool random_rotation = true;            // each agent's ground sprite turned differently
uniform bool show_dead = true;                  // also under corpses (dead / decomposing)
uniform float ground_offset = 0.02;             // just above the ground (no flicker with it)

uniform sampler2D agent_data : filter_nearest, repeat_disable;
uniform int tex_width = 1024;
uniform float world_height = 48.0;

// Smooth movement between simulation ticks (set by the renderer every frame).
// agent_prev = the same data, one tick earlier. Drawn at mix(previous, new, interp_alpha).
// interp_alpha = 1: no blending (the new position, as before).
uniform sampler2D agent_prev : filter_nearest, repeat_disable;
uniform float interp_alpha = 1.0;
uniform float interp_max_jump = 8.0;            // farther in one tick: not blended (slot reused...)

// Wrap view (set by the renderer's set_wrap_view(): wrap_axes = 0 means off)
uniform vec3 world_size = vec3(100.0);
uniform vec3 wrap_axes = vec3(0.0);
global uniform vec3 wrap_center;
global uniform float planet_radius;

varying vec3 v_up;


// --- Helpers (same as the sprite shader) -------------------------------------

float hash1(int n) {
	return fract(sin(float(n) * 12.9898) * 43758.5453);
}

// The position to draw: between the previous tick's and this tick's (interp_alpha).
// New agents (no previous), and moves longer than interp_max_jump, aren't blended.
vec3 blended_pos(ivec2 px, vec3 cur) {
	if (interp_alpha >= 0.999) return cur;
	ivec2 ps = textureSize(agent_prev, 0);
	if (px.x >= ps.x || px.y >= ps.y) return cur;
	vec4 dp = texelFetch(agent_prev, px, 0);
	if ((int(dp.w + 0.5) & 3) == 0) return cur;          // free slot last tick: just appeared
	float yp = float(int(dp.z + 0.5) >> 12) / 4095.0 * world_height;
	vec3 dd = vec3(dp.x, yp, dp.y) - cur;
	dd.xz -= world_size.xz * round(dd.xz / max(world_size.xz, vec2(1e-6)));   // through the border
	if (dot(dd, dd) > interp_max_jump * interp_max_jump) return cur;
	return cur + dd * (1.0 - interp_alpha);
}


// The copy of p closest to ref (shortest way through the borders)
vec3 nearest_image(vec3 p, vec3 ref) {
	vec3 d = p - ref;
	d -= wrap_axes * world_size * round(d / max(world_size, vec3(1e-6)));
	return ref + d;
}

// Little planet: wrap the flat world onto a sphere of radius planet_radius that touches
// the ground (y = 0) at wrap_center. `up` returns the planet's local up at that point.
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

// Visible radius on the planet: a circle of half the world, never past the far side.
float planet_limit() {
	return min(min(world_size.x, world_size.z) * 0.5, PI * planet_radius * 0.97);
}


// --- Vertex ------------------------------------------------------------------

void vertex() {
	ivec2 px = ivec2(INSTANCE_ID % tex_width, INSTANCE_ID / tex_width);
	vec4 d = texelFetch(agent_data, px, 0);
	if (px.y >= textureSize(agent_data, 0).y) d = vec4(0.0);   // not in this (older) tick yet

	// A: state (2 bits), size (8 bits at << 6)
	int v = int(d.w + 0.5);
	int state = v & 3;
	float size = float((v >> 6) & 255) * 0.1;

	// On the ground under the agent (its height is ignored), near the view, on the planet
	vec3 at = blended_pos(px, vec3(d.x, 0.0, d.y));          // smooth between ticks
	vec3 flat_pos = nearest_image(MODEL_MATRIX[3].xyz + vec3(at.x, ground_offset, at.z), wrap_center);
	vec3 up;
	vec3 center = curve(flat_pos, up);
	v_up = up;
	bool past_horizon = planet_radius > 0.0
			&& distance(flat_pos.xz, wrap_center.xz) > planet_limit();
	bool shown = state == 1 || (show_dead && state >= 2);

	if (!shown || past_horizon) {
		VERTEX = vec3(0.0);                          // free slot, corpse, or past the horizon
	} else {
		// Flat on the surface, fixed in the world: x = east, y = south, z = up
		vec3 east = normalize(vec3(1.0, 0.0, 0.0) - up * up.x);
		vec3 south = normalize(cross(east, up));

		// Quad (-0.5..0.5) with the texture's proportions
		vec2 tex_size = vec2(textureSize(ground_texture, 0));
		vec2 local = VERTEX.xy;
		local.y *= tex_size.y / max(tex_size.x, 1.0);
		if (random_rotation) {
			float a = hash1(INSTANCE_ID) * 6.2832;
			local = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * local;
		}
		local *= ground_scale * (ground_scales_with_size ? size : 1.0);

		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
				vec4(east, 0.0),
				vec4(south, 0.0),
				vec4(up, 0.0),
				vec4(center, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
		VERTEX = vec3(local, 0.0);
	}
}


// --- Fragment ----------------------------------------------------------------

void fragment() {
	vec4 tex = texture(ground_texture, UV);
	ALBEDO = tex.rgb * tint.rgb;
	ALPHA = tex.a * tint.a;
	EMISSION = ALBEDO * (receive_shadow ? shade_color.rgb : vec3(1.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(v_up, 0.0)).xyz);
	ROUGHNESS = 1.0;
}


void light() {
	if (receive_shadow && LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += (vec3(1.0) - shade_color.rgb) * ATTENUATION;
	}
}