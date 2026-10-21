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

void vertex() {
	ivec2 px = ivec2(INSTANCE_ID % tex_width, INSTANCE_ID / tex_width);

	vec4 d = texelFetch(agent_data, px, 0);   // x, z, size, state
	v_state = d.w;

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
}


void fragment() {
	vec4 c = v_state < 0.5 ? corpse_color : alive_color;
	ALBEDO = c.rgb;

	vec4 tex = texture(sprite_texture, UV);
	ALBEDO = tex.rgb * COLOR.rgb; // COLOR = per-instance tint
	ALPHA = tex.a * COLOR.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff; // hard edges, no sorting issues
}
