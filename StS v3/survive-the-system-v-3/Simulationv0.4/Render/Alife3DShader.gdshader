shader_type spatial;
render_mode cull_disabled, unshaded;

// ---------------------------------------------------------------------------
// agent_data texture: 1 texel (RGBA32F) per agent
//   R = x
//   G = z
//   B = y (12 bits, 0..world_height) << 12  |  color RGB 4:4:4 (12 bits)
//   A = state (2) | action (4) << 2 | size (6) << 6 | life cycle (12) << 12
// state: 0 = FREE (not drawn), 1 = ALIVE, 2 = DEAD, 3 = DECOMPOSING
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

// Picked agent (-1 = none), set from GDScript on click
uniform int selected_id = -1;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int outline_px : hint_range(1, 8) = 1;



varying flat int state;
varying flat int action;
varying flat int life_cycle;
varying float size;
varying flat vec3 agent_color;
varying float is_selected;

uniform int hframes = 1;      // columns: life cycle
uniform int vframes = 1;      // rows: for later
// 0 = life_cycle is directly the column index.
// > 0 = life_cycle goes from 0 to life_span and is spread across the columns.
uniform int life_span = 0;

varying flat vec2 frame;      // (column, row) of the current frame

uniform vec3 world_size = vec3(100.0);
uniform vec3 wrap_axes = vec3(0.0);     // 1.0 on axes that wrap

// The copy of p closest to ref (shortest way through the borders)
vec3 nearest_image(vec3 p, vec3 ref) {
	vec3 d = p - ref;
	d -= wrap_axes * world_size * round(d / max(world_size, vec3(1e-6)));
	return ref + d;
}

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



// --- Wind (set wind_strength = 0 for species that shouldn't sway, e.g. animals) ---
uniform float wind_strength = 0.0;              // tip displacement relative to height (grass: ~0.3)
uniform vec2  wind_direction = vec2(1.0, 0.3);  // world x, z
uniform float wind_speed = 1.5;                 // how fast blades move
uniform float wind_wave_scale = 0.15;           // size of the waves across the field
uniform float wind_gust = 0.7;                  // 0 = steady breeze, 1 = strong gusts

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

void vertex() {
	ivec2 px = ivec2(INSTANCE_ID % tex_width, INSTANCE_ID / tex_width);
	vec4 d = texelFetch(agent_data, px, 0);

	// --- A: state, action, size, life cycle ---
	int v = int(d.w + 0.5);
	state      = v & 3;
	action     = (v >> 2) & 15;
	size       = float((v >> 6) & 255) * 0.1;      // 8 bits: 0 to 25.5
	life_cycle = (v >> 14) & 1023;                 // 10 bits: 0 to 1023
	
	int column = (life_span > 0) ? (life_cycle * hframes) / life_span : life_cycle;
	column = clamp(column, 0, hframes - 1);
	frame = vec2(float(column), 0.0);          // row 0 for now

	// --- B: y + color ---
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

	if (state == 0) {
		// FREE slot: all 4 corners on the same point -> zero-area quad, not drawn
		VERTEX = vec3(0.0);
	} else {
		vec3 up = vec3(0.0, 1.0, 0.0);
		vec3 right = normalize(cross(up, MAIN_CAM_INV_VIEW_MATRIX[2].xyz));
		vec3 fwd   = normalize(cross(MAIN_CAM_INV_VIEW_MATRIX[0].xyz, up));

		// --- Wind: bend the top, keep the base fixed ---
		if (wind_strength > 0.0 && state == 1) {         // only living plants sway
			float t = 1.0 - UV.y;                          // 0 at the base, 1 at the tip
			float sway = wind_sway(vec2(d.x, d.y), hash1(INSTANCE_ID) * 6.2832, TIME);
			vec3 wind_world = vec3(wind_direction.x, 0.0, wind_direction.y);
			wind_world = normalize(wind_world) * sway * wind_strength;
			// world wind -> the billboard's local axes
			vec3 bend = vec3(dot(wind_world, right), 0.0, dot(wind_world, fwd));
			VERTEX += bend * VERTEX.y * t;                 // grows with height: the tip moves most
			VERTEX.y *= 1.0 - 0.15 * sway * wind_strength * t;   // shorten a bit when bent
		}

		vec3 cam_pos = MAIN_CAM_INV_VIEW_MATRIX[3].xyz;
		vec3 agent = nearest_image(MODEL_MATRIX[3].xyz + vec3(d.x, y, d.y), cam_pos);

		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
				vec4(right, 0.0),
				vec4(up, 0.0),
				vec4(fwd, 0.0),
				vec4(agent, 1.0));     

		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);

		VERTEX *= size;

		is_selected = (INSTANCE_ID == selected_id) ? 1.0 : 0.0;
		if (is_selected > 0.5) {
			vec2 tex_size = vec2(textureSize(sprite_texture, 0));
			vec2 grow = 1.0 + 2.0 * float(outline_px) / frame_px();
			VERTEX.xy *= grow;
			UV = (UV - 0.5) * grow + 0.5;
		}
	}
}


void fragment() {
	float a = sprite_alpha(UV, frame);
	vec4 tex = texture(sprite_texture, sheet_uv(UV, frame));

	vec3 tint = agent_color;
	if (state == 2) {
		tint = corpse_color.rgb;                          // dead
	} else if (state == 3) {
		tint = corpse_color.rgb * (1.0 - decompose_darken);  // decomposing
	}

	ALBEDO = tex.rgb * tint;
	ALPHA = a;

	// Shape-following outline, only for the selected agent
	if (is_selected > 0.5 && a < alpha_cutoff) {
		vec2 texel = 1.0 / vec2(textureSize(sprite_texture, 0));
		float r2 = float(outline_px * outline_px) + 0.5;
		float near = 0.0;
		for (int oy = -outline_px; oy <= outline_px; oy++) {
			for (int ox = -outline_px; ox <= outline_px; ox++) {
				if (float(ox * ox + oy * oy) <= r2) {
					near = max(near, sprite_alpha(UV + vec2(float(ox), float(oy)) * texel, frame));				}
			}
		}
		if (near >= alpha_cutoff) {
			ALBEDO = outline_color.rgb;
			ALPHA = 1.0;
		}
	}
	

	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;   // hard edges, no sorting issues
}
