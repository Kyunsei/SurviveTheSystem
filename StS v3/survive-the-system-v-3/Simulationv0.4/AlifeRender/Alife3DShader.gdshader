shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, specular_disabled;
// Lit only to receive the sun's shadow (see light() at the end): in the sun the sprite looks
// exactly as before (unshaded), in shadow it is multiplied by shade_color.

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

// Shadow from the sun (DirectionalLight3D with shadows on). Colour of the sprite in full
// shadow, relative to its sunlit colour. receive_shadow off: always as in the sun.
uniform bool receive_shadow = true;
uniform vec4 shade_color : source_color = vec4(0.45, 0.48, 0.62, 1.0);

uniform sampler2D agent_data : filter_nearest, repeat_disable;
uniform int tex_width = 1024;
uniform float world_height = 48.0;

// Smooth movement between simulation ticks (set by the renderer every frame).
// agent_prev = the same data, one tick earlier. Drawn at mix(previous, new, interp_alpha).
// interp_alpha = 1: no blending (the new position, as before).
uniform sampler2D agent_prev : filter_nearest, repeat_disable;
uniform float interp_alpha = 1.0;
uniform float interp_max_jump = 8.0;            // farther in one tick: not blended (slot reused...)

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

// Several sprites per agent (e.g. moss). The multimesh then has `copies` instances per
// agent: instance = agent * copies + k. How many are shown grows with the life cycle
// (1, then 2 from stage_for_2, 3 from stage_for_3); each sits at its own spot around the
// agent (copy_offset_k, world units x the agent's size) and can be mirrored at random.
// copies = 1 (default): one sprite per agent, as before.
uniform int copies = 1;                          // 1 to 3
uniform int stage_for_2 = 2;
uniform int stage_for_3 = 4;
uniform vec2 copy_offset_0 = vec2(0.0, 0.0);
uniform vec2 copy_offset_1 = vec2(0.3, 0.2);
uniform vec2 copy_offset_2 = vec2(-0.3, 0.25);
uniform bool copy_rotate_layout = true;          // turn the layout randomly per agent
uniform bool copy_random_flip = true;            // mirror some copies (random "orientation")
uniform bool copy_offsets_with_size = true;      // false: copies stay put as the agent grows
// Random layout instead of copy_offset_k: each agent gets its own random spots within
// copy_radius of its centre (spread around it, so copies don't pile up)
uniform bool copy_random_layout = false;
uniform float copy_radius = 0.35;                // world units (x size if copy_offsets_with_size)
uniform bool copy_first_centered = true;         // copy 0 stays on the centre

// Sprite size = sprite_scale (per species, set by the renderer from ALIFE.sprite_scale)
//             x the agent's size, if scale_sprite_with_size (default)
// scale_sprite_with_size off (e.g. moss): only sprite_scale, the sprite never grows
uniform float sprite_scale = 1.0;
uniform bool scale_sprite_with_size = true;

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

// Damage feedback (written by DamageEffects: a small ring of recent hits per species).
// HIT_SLOTS must match DamageEffects.SLOTS.
#define HIT_SLOTS 16
uniform bool hit_active = false;              // false = no recent hit: skip the loop
uniform int hit_ids[HIT_SLOTS];               // agent index (-1 = empty slot)
uniform float hit_start[HIT_SLOTS];           // when it was hit (DamageEffects clock)
uniform float hit_strength[HIT_SLOTS];        // 0..1
uniform float hit_now = 0.0;                  // DamageEffects clock, now
uniform float hit_time = 0.35;                // seconds the effect lasts
uniform vec4 hit_color : source_color = vec4(1.0, 0.12, 0.08, 1.0);
uniform float hit_shake = 0.12;               // sideways shake, relative to the sprite width
uniform float hit_squash : hint_range(0.0, 0.6) = 0.2;

varying flat int state;
varying flat int action;
varying flat int life_cycle;
varying float size;
varying flat vec3 agent_color;
varying float is_selected;
varying flat vec2 frame;      // (column, row) of the current frame
varying flat float hit_amount;   // 0..1, fades out after a hit
varying vec3 v_up;               // ground's up (world), used as the normal for lighting


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


// 0..1: how hurt this agent looks right now (1 = just hit hard, fades to 0)
float hit_level(int id) {
	float h = 0.0;
	for (int k = 0; k < HIT_SLOTS; k++) {
		if (hit_ids[k] == id) {
			float age = hit_now - hit_start[k];
			if (age >= 0.0 && age < hit_time) {
				h = max(h, hit_strength[k] * (1.0 - age / hit_time));
			}
		}
	}
	return h;
}


// --- Vertex ------------------------------------------------------------------

void vertex() {
	int n_copies = clamp(copies, 1, 3);
	int agent_id = INSTANCE_ID / n_copies;           // the agent this sprite belongs to
	int k = INSTANCE_ID % n_copies;                  // which of its copies
	ivec2 px = ivec2(agent_id % tex_width, agent_id / tex_width);
	vec4 d = texelFetch(agent_data, px, 0);
	if (px.y >= textureSize(agent_data, 0).y) d = vec4(0.0);   // not in this (older) tick yet

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
	hit_amount = hit_active ? hit_level(agent_id) : 0.0;

	// Several sprites per agent: how many at this life stage, and where this one sits
	vec2 copy_off = vec2(0.0);
	bool copy_hidden = false;
	if (n_copies > 1) {
		int shown = 1;
		if (life_cycle >= stage_for_2) shown = 2;
		if (life_cycle >= stage_for_3) shown = 3;
		copy_hidden = k >= min(shown, n_copies);
		if (copy_random_layout) {
			if (k == 0 && copy_first_centered) {
				copy_off = vec2(0.0);
			} else {
				// A third of a turn apart (+ some jitter), at a random distance in the radius
				float a = hash1(agent_id * 7 + 3) * 6.2832 + float(k) * 2.0944
						+ (hash1(agent_id * 31 + k * 7) - 0.5) * 1.4;
				float r = copy_radius * mix(0.4, 1.0, hash1(agent_id * 19 + k * 11));
				copy_off = vec2(cos(a), sin(a)) * r;
			}
		} else {
			copy_off = (k == 0) ? copy_offset_0 : ((k == 1) ? copy_offset_1 : copy_offset_2);
			if (copy_rotate_layout) {
				float a = hash1(agent_id * 7 + 3) * 6.2832;
				copy_off = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * copy_off;
			}
		}
		if (copy_offsets_with_size) {
			copy_off *= size;                        // spread out as the agent grows
		}                                            // else: world units, never move
		if (copy_random_flip && hash1(INSTANCE_ID * 13 + 5) > 0.5) {
			UV.x = 1.0 - UV.x;                       // mirrored copy
		}
	}

	// Where the agent is drawn: the copy near the view (wrap), bent onto the little planet
	vec3 at = blended_pos(px, vec3(d.x, y, d.y));            // smooth between ticks
	vec3 flat_pos = nearest_image(MODEL_MATRIX[3].xyz + vec3(at.x + copy_off.x, at.y, at.z + copy_off.y), wrap_center);
	vec3 up;
	vec3 agent = curve(flat_pos, up);
	v_up = up;
	bool past_horizon = planet_radius > 0.0
			&& distance(flat_pos.xz, wrap_center.xz) > planet_limit();

	if (state == 0 || agent_id == hidden_id || past_horizon || copy_hidden) {
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

		// Hit: squashed by the blow, then shaking sideways while it fades
		if (hit_amount > 0.0) {
			VERTEX.y *= 1.0 - hit_squash * hit_amount;
			VERTEX.x *= 1.0 + hit_squash * 0.5 * hit_amount;
			VERTEX.x += sin(hit_now * 70.0 + float(INSTANCE_ID)) * hit_shake * hit_amount;
		}

		VERTEX *= sprite_scale * (scale_sprite_with_size ? size : 1.0);

		is_selected = (agent_id == selected_id) ? 1.0 : 0.0;
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

	// Hit flash: white at the impact, then red, fading out
	if (hit_amount > 0.0) {
		vec3 flash = mix(hit_color.rgb, vec3(1.0), smoothstep(0.7, 1.0, hit_amount));
		base = mix(base, flash, 0.85 * hit_amount);
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

	// Shadow: the shaded part is emission, the sun adds the rest (see light())
	EMISSION = ALBEDO * (receive_shadow ? shade_color.rgb : vec3(1.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(v_up, 0.0)).xyz);   // flat: no side shading
	ROUGHNESS = 1.0;
}


// Sun only, no N.L: in the sun = ALBEDO (like unshaded), in shadow = ALBEDO x shade_color.
// The light's energy and color are ignored on purpose, to keep the pixel-art colors.
void light() {
	if (receive_shadow && LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += (vec3(1.0) - shade_color.rgb) * ATTENUATION;
	}
}