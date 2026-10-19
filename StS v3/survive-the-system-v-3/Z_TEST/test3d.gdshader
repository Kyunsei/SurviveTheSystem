shader_type spatial;

uniform sampler2D agent_data : filter_nearest, repeat_disable;
uniform int tex_width = 1024;
uniform vec4 alive_color : source_color = vec4(0.31, 0.66, 0.40, 1.0);
uniform vec4 corpse_color : source_color = vec4(0.49, 0.08, 0.15, 1.0);

varying flat float v_state;

void vertex() {
	ivec2 px = ivec2(INSTANCE_ID % tex_width, INSTANCE_ID / tex_width);
	vec4 d = texelFetch(agent_data, px, 0);   // x, z, size, state
	v_state = d.w;
	if (d.z < 0.5) {
		VERTEX = VERTEX  + vec3(d.x, 0.0, d.y); //vec3(0.0);                   // FREE slot: collapsed, not drawn
	} else {
		VERTEX = VERTEX  + vec3(d.x, 0.0, d.y);   // 2D (x, y) → ground (x, 0, z)
	}
}



void fragment() {
	vec4 c = v_state < 0.5 ? corpse_color : alive_color;
	ALBEDO = c.rgb;
}