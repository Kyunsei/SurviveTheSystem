shader_type spatial;
render_mode cull_disabled, unshaded;

// ---------------------------------------------------------------------------
// agent_data texture: 1 texel (RGBA32F) per agent
//   R = x
//   G = z
//   B = y (12 bits, 0..world_height) << 12  |  color RGB 4:4:4 (12 bits)
//   A = state (2) | action (4) << 2 | size (8) << 6 | life cycle (10) << 14
// state: 0 = FREE (not drawn), 1 = ALIVE, 2 = DEAD, 3 = DECOMPOSING
//
// Needs two Shader Globals (Project Settings > Globals > Shader Globals):
//   wrap_center   vec3    (set by FlyCamera)
//   planet_radius float   (set by PlayerController, 0 = flat)
// ---------------------------------------------------------------------------

uniform sampler2D sprite_texture : source_color, filter_nearest;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;

uniform sampler2D agent_data : filter_nearest, repeat_disable;
uniform int tex_width = 1024;
uniform float world_height = 48.0;

// Used when an agent has no color set (packed color == 0)
uniform vec4 alive_color : source_color = vec4(0.31, 0.66, 0.40, 1.0);
uniform vec4 corpse_color : source_color = vec4(0.49, 0.08, 0.15, 1.0);
uniform float decompose_darken : hint_range(0.0, 1.0) = 0.5;

// Outlined agent (-1 = none) and hidden agent (first person, -1 = none)
uniform int selected_id = -1;
uniform int hidden_id = -1;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int outline_px : hint_range(1, 8) = 1;

// Sprite sheet: columns = life cycle
uniform int hframes = 1;
uniform int vframes = 1;
// 0 = life_cycle is directly the column index.
// > 0 = life_cycle goes from 0 to life_span and is spread across the columns.
uniform int life_span = 0;

// Wrap view (set by the renderer's set_wrap_view(): wrap_axes = 0 means off)
uniform vec3 world_size = vec3(100.0);
uniform vec3 wrap_axes = vec3(0.0);
global uniform vec3 wrap_center;
global uniform float planet_radius;

// Wind (wind_strength = 0 for species that shouldn't sway, e.g. animals)
uniform float wind_strength = 0.0;              // tip displacement relative to height (grass: ~0.3)
uniform vec2  wind_direction = vec2(1.0, 0.3);  // world x, z
uniform float wind_speed = 1.5;
uniform float wind_wave_scale = 0.15;
uniform float wind_gust = 0.7;

// Action visuals (per species, -1 = off). Set to the current_action value of each move,
// e.g. the spidercrab's setup_hunt_visuals(): charge = 2, dash = 3, recover = 4.
uniform int action_charge = -1;     // crouch + flashing warning color (the "tell")
uniform int action_dash = -1;       // stretched forward, bright
uniform int action_recover = -1;    // squashed, dull
uniform vec4 charge_color : source_color = vec4(1.0, 0.25, 0.15, 1.0);
uniform float charge_flash_speed = 14.0;
uniform float charge_crouch : hint_range(0.0, 0.5) = 0.25;   // how much it squats while charging
uniform float dash_stretch : hint_range(0.0, 1.0) = 0.35;
uniform vec4 recover_tint : source_color = vec4(0.55, 0.55, 0.65, 1.0);

varying flat int state;
varying flat int action;
varying flat int life_cycle;
varying float size;
varying flat vec3 agent_color;
varying float is_selected;
varying flat vec2 frame;      // (column, row) of the current frame


// --- Helpers -----------------------------------------------------------------

vec2 frame_px() {
	return vec2(textureSize(sprite_texture, 0)) / vec2(float(hframes), float(vframes));
}

// Local UV (0..1 on the sprite) -> UV in the sprite sheet
vec2 sheet_uv(vec2 local, vec2 f) {
	vec2 half_texel = 0.5 / frame_px();
	local = clamp(local, half_texel, 1.0 - half_texel);   // never bleed into the next frame
	return (local + f) / vec2(float(hframes), float(vframes));
}

float sprite_alpha(vec2 uv, vec2 f) {
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		return 0.0;
	}
	return texture(sprite_texture, sheet_uv(uv, f)).a;
}

float hash1(int n) {
	return fract(sin(float(n) * 12.9898) * 43758.5453);
}

// 0..1: how much a blade at world position p leans downwind right now
float wind_sway(vec2 p, float phase, float t) {
	vec2 dir = normalize(wind_direction);
	float along = dot(p, dir) * wind_wave_scale;
	float gust    = 0.5 + 0.5 * sin(t * wind_speed * 0.3 - along * 0.4);     // slow waves
	float flutter = 0.5 + 0.5 * sin(t * wind_speed * 2.0 - along + phase);  // fast, per blade
	return mix(1.0, gust, wind_gust) * (0.6 + 0.4 * flutter);
}

// The copy of p closest to ref (shortest way through the borders)
vec3 nearest_image(vec3 p, vec3 ref) {
	vec3 d = p - ref;
	d -= wrap_axes * world_size * round(d / max(world_size, vec3(1e-6)));
	return ref + d;
}

// Little planet: wrap the flat world onto a sphere of radius planet_radius that touches
// the ground (y = 0) at wrap_center. Heights above the ground stay heights.
// `up` returns the planet's local up (its surface normal) at that point.
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

	// A: state, action, size, life cycle
	int v = int(d.w + 0.5);
	state      = v & 3;
	action     = (v >> 2) & 15;
	size       = float((v >> 6) & 255) * 0.1;      // 8 bits: 0 to 25.5
	life_cycle = (v >> 14) & 1023;                 // 10 bits: 0 to 1023

	int column = (life_span > 0) ? (life_cycle * hframes) / life_span : life_cycle;
	frame = vec2(float(clamp(column, 0, hframes - 1)), 0.0);   // row 0 for now

	// B: y + color
	int b = int(d.z + 0.5);
	int col = b & 4095;
	float y = float(b >> 12) / 4095.0 * world_height;
	if (col == 0) {
		agent_color = alive_color.rgb;               // no color set: species default
	} else {
		vec3 srgb = vec3(float((col >> 8) & 15), float((col >> 4) & 15), float(col & 15)) / 15.0;
		agent_color = pow(srgb, vec3(2.2));          // sRGB -> linear
	}

	is_selected = 0.0;

	// Where the agent is drawn: the copy near the view (wrap), bent onto the little planet
	vec3 flat_pos = nearest_image(MODEL_MATRIX[3].xyz + vec3(d.x, y, d.y), wrap_center);
	vec3 up;
	vec3 agent = curve(flat_pos, up);
	bool past_horizon = planet_radius > 0.0
			&& distance(flat_pos.xz, wrap_center.xz) > planet_limit();

	if (state == 0 || INSTANCE_ID == hidden_id || past_horizon) {
		// FREE slot, first-person agent, or outside the planet's circle: not drawn
		VERTEX = vec3(0.0);
	} else {
		// Billboard standing on the planet: "up" is the surface normal, facing the camera
		vec3 right = cross(up, MAIN_CAM_INV_VIEW_MATRIX[2].xyz);
		if (dot(right, right) < 1e-6) {
			right = MAIN_CAM_INV_VIEW_MATRIX[0].xyz;     // looking straight along "up"
		}
		right = normalize(right);
		vec3 fwd = normalize(cross(right, up));

		// Wind: bend the top, keep the base fixed (uses the real position: no jump on wrap)
		if (wind_strength > 0.0 && state == 1) {
			float t = 1.0 - UV.y;                          // 0 at the base, 1 at the tip
			float sway = wind_sway(vec2(d.x, d.y), hash1(INSTANCE_ID) * 6.2832, TIME);
			vec3 wind_world = normalize(vec3(wind_direction.x, 0.0, wind_direction.y)) * sway * wind_strength;
			vec3 bend = vec3(dot(wind_world, right), 0.0, dot(wind_world, fwd));
			VERTEX += bend * VERTEX.y * t;
			VERTEX.y *= 1.0 - 0.15 * sway * wind_strength * t;
		}

		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
				vec4(right, 0.0),
				vec4(up, 0.0),
				vec4(fwd, 0.0),
				vec4(agent, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);

		// Action shapes (local sprite space: x = across, y = up from the feet)
		if (action == action_charge) {
			// Squat lower and wider, trembling slightly: about to spring
			float shake = sin(TIME * 60.0 + float(INSTANCE_ID)) * 0.02;
			VERTEX.y *= 1.0 - charge_crouch;
			VERTEX.x *= 1.0 + charge_crouch * 0.6;
			VERTEX.x += shake * VERTEX.y;
		} else if (action == action_dash) {
			// Long and low: a streak
			VERTEX.x *= 1.0 + dash_stretch;
			VERTEX.y *= 1.0 - dash_stretch * 0.4;
		} else if (action == action_recover) {
			// Slumped and breathing
			float breath = 0.5 + 0.5 * sin(TIME * 6.0 + float(INSTANCE_ID));
			VERTEX.y *= 0.85 + 0.05 * breath;
		}

		VERTEX *= size;

		is_selected = (INSTANCE_ID == selected_id) ? 1.0 : 0.0;
		if (is_selected > 0.5) {
			vec2 grow = 1.0 + 2.0 * float(outline_px) / frame_px();
			VERTEX.xy *= grow;
			UV = (UV - 0.5) * grow + 0.5;
		}
	}
}


// --- Fragment ----------------------------------------------------------------

void fragment() {
	float a = sprite_alpha(UV, frame);
	vec4 tex = texture(sprite_texture, sheet_uv(UV, frame));

	vec3 base = tex.rgb * agent_color;
	if (state >= 2) {
		// Dead / decomposing: corpse color, keeping the sprite's shading
		float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		base = corpse_color.rgb * (0.4 + 0.8 * lum);
		if (state == 3) {
			base *= 1.0 - decompose_darken;
		}
	}
	// Action colors (alive only)
	if (state == 1) {
		if (action == action_charge) {
			float flash = 0.5 + 0.5 * sin(TIME * charge_flash_speed);
			base = mix(base, charge_color.rgb, 0.25 + 0.5 * flash);   // warning blink
		} else if (action == action_dash) {
			base = base * 1.3 + vec3(0.1);                             // bright streak
		} else if (action == action_recover) {
			base *= recover_tint.rgb;                                  // tired, dull
		}
	}

	ALBEDO = base;
	ALPHA = a;

	// Shape-following outline, only for the selected agent
	if (is_selected > 0.5 && a < alpha_cutoff) {
		vec2 texel = 1.0 / frame_px();
		float r2 = float(outline_px * outline_px) + 0.5;
		float near = 0.0;
		for (int oy = -outline_px; oy <= outline_px; oy++) {
			for (int ox = -outline_px; ox <= outline_px; ox++) {
				if (float(ox * ox + oy * oy) <= r2) {
					near = max(near, sprite_alpha(UV + vec2(float(ox), float(oy)) * texel, frame));
				}
			}
		}
		if (near >= alpha_cutoff) {
			ALBEDO = outline_color.rgb;
			ALPHA = 1.0;
		}
	}

	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;   // hard edges, no sorting issues
}