shader_type spatial;
// Add "unshaded" here if your sprites shouldn't react to lights
render_mode cull_disabled, unshaded;

uniform sampler2D sprite_texture : source_color, filter_nearest;
uniform int hframes = 1;
uniform int vframes = 1;
uniform bool billboard = true;        // always face the camera
uniform bool billboard_y_only = false; // only rotate around Y (good for characters)
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;



uniform sampler2D agent_data : filter_nearest, repeat_disable;
uniform int tex_width = 1024;
uniform vec4 alive_color : source_color = vec4(0.31, 0.66, 0.40, 1.0);
uniform vec4 corpse_color : source_color = vec4(0.49, 0.08, 0.15, 1.0);

varying flat float v_state;

// ID of the picked agent (-1 = none). Set from GDScript on click.
uniform int selected_id = -1;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Outline thickness as a fraction of the sprite size (0.3 = 30% on each side).
uniform int outline_px : hint_range(1, 8) = 1;

varying float is_selected;

const float SIZE_MIN = 0.5;
const float SIZE_MAX = 100.0;
varying	flat int state ;
varying flat int action ;
varying	float size  ;
varying	flat int life_cycle;


// Alpha of the sprite at uv, treating everything outside the sprite as empty.
float sprite_alpha(vec2 uv) {
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		return 0.0;
	}
	return texture(sprite_texture, uv).a;
}



void vertex() {
	ivec2 px = ivec2(INSTANCE_ID % tex_width, INSTANCE_ID / tex_width);

	vec4 d = texelFetch(agent_data, px, 0);   // x,y, z, state
	
	int v = int(d.w + 0.5); //size,action,state,lifecycle compile in one int
	state  = v & 3;
	action = (v >> 2) & 15;
	size   = mix(SIZE_MIN, SIZE_MAX, float((v >> 6) & 63) / 63.0);
	life_cycle    = v >> 12;
	
	
	//v_state = d.w;

	// sprite frame from custom data
	//float f = floor(INSTANCE_CUSTOM.r + 0.5);
	//vec2 cell = vec2(mod(f, float(hframes)), floor(f / float(hframes)));
	//UV = (UV + cell) / vec2(float(hframes), float(vframes));

	// collapse FREE slots to a degenerate quad
	//VERTEX *= (d.z < 0.5) ? 0.0 : d.z;

	// world-space position: instance origin + agent offset
   // if (d.z < 0.5) {
   //     VERTEX = VERTEX  + vec3(d.x, 0.0, d.y); //vec3(0.0);                   // FREE slot: collapsed, not drawn
  //  } else {
  //      VERTEX = VERTEX  + vec3(d.x, 0.0, d.y);   // 2D (x, y) → ground (x, 0, z)
  //  }	

	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(normalize(cross(vec3(0.0, 1.0, 0.0), MAIN_CAM_INV_VIEW_MATRIX[2].xyz)), 0.0),
			vec4(0.0, 1.0, 0.0, 0.0),
			vec4(normalize(cross(MAIN_CAM_INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
			MODEL_MATRIX[3] + vec4(d.x, 0.0, d.y, 0.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	
	VERTEX *= size;
	
	is_selected = (INSTANCE_ID == selected_id) ? 1.0 : 0.0;
	if (is_selected > 0.5) {
		vec2 tex_size = vec2(textureSize(sprite_texture, 0));
		vec2 grow = 1.0 + 2.0 * float(outline_px) / tex_size;
		VERTEX.xy *= grow;
		UV = (UV - 0.5) * grow + 0.5;
	}
}


void fragment() {

	float a = sprite_alpha(UV);
	vec4 tex = texture(sprite_texture, clamp(UV, 0.0, 1.0));

	// Base sprite colour.
	vec4 state_col = state < 1 ? corpse_color : alive_color;
	ALBEDO = tex.rgb * COLOR.rgb;   // * state_col.rgb  COLOR = per-instance tint
	ALPHA = a * COLOR.a;

	// Shape-following outline: an empty pixel becomes outline if any opaque
	// sprite pixel lies within outline_px texels (round brush).
	// Only runs for the selected agent, so it costs nothing for the others.
	if (is_selected > 0.5 && a < alpha_cutoff) {
		vec2 texel = 1.0 / vec2(textureSize(sprite_texture, 0));
		float r2 = float(outline_px * outline_px) + 0.5;
		float near = 0.0;
		for (int y = -outline_px; y <= outline_px; y++) {
			for (int x = -outline_px; x <= outline_px; x++) {
				if (float(x * x + y * y) <= r2) {
					near = max(near, sprite_alpha(UV + vec2(float(x), float(y)) * texel));
				}
			}
		}
		if (near >= alpha_cutoff) {
			ALBEDO = outline_color.rgb;
			ALPHA = 1.0;
		}
	
	}
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;   // hard edges, no sorting issues
	//if (is_selected > 0.5) { ALBEDO = vec3(1.0, 0.0, 1.0); ALPHA = 1.0; }   // DEBUG
}
