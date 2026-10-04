shader_type canvas_item;

uniform sampler2D agent_data : filter_nearest, repeat_disable;
uniform int tex_width = 1024;
uniform vec4 alive_color : source_color = vec4(0.31, 0.66, 0.40, 1.0);
uniform vec4 corpse_color : source_color = vec4(0.49, 0.08, 0.15, 0.2);

varying flat float v_state;

void vertex() {
    // Which pixel in data_texture belongs to this instance
    ivec2 px = ivec2(INSTANCE_ID % tex_width, INSTANCE_ID / tex_width);
    vec4 d = texelFetch(agent_data, px, 0);   // x, y, size, state
    v_state = d.w;

    if (d.w < 0.5) {
        VERTEX = VERTEX + d.xy;//vec2(0.0);                   // FREE slot: collapse it, nothing gets drawn
    } else {
        //VERTEX = VERTEX * d.z + d.xy;         // scale by size, then move to position
		VERTEX = VERTEX + d.xy;         }
}

void fragment() {
    vec4 base = texture(TEXTURE, UV);         // white if the mesh has no texture
    COLOR = base * (v_state > 1.5 ? corpse_color : alive_color);
}