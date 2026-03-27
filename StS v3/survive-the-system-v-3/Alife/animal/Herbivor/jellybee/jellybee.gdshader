shader_type spatial;
//render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
render_mode  cull_disabled, unshaded,  blend_mix;// world_vertex_coords;
uniform vec4 albedo : source_color;
uniform sampler2D albedo_texture : source_color, filter_nearest;//, filter_linear_mipmap, repeat_enable;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0, 0.001) =0.5;


//uniform float all_position[3*1000];

uniform ivec2 tile_count = ivec2(4, 4);
uniform ivec2 tile_index = ivec2(0, 0);
uniform int nframe = 3;

//instance uniform vec4 tint_color = vec4(0., 0.00, 0.00, 1.0);
varying flat int id;
varying flat vec4 data;
varying flat vec4 col;


///
uniform vec3 player_position;



void vertex() {
    id = INSTANCE_ID;
	data = INSTANCE_CUSTOM;
	col = COLOR.rgba;

	

    // Object world-space position (translation part of MODEL_MATRIX)
    vec3 obj_pos = vec3(MODEL_MATRIX[3].xyz);

    // We want to face the player only around Y, so build a direction with same Y as object
    vec3 target = vec3(player_position.x, obj_pos.y, player_position.z);
    vec3 to_player = normalize(target - obj_pos);



    // Compute yaw angle so the quad's forward (-Z in Godot) looks at the player.
    // atan(y, x) variant: yaw = atan2(x, z)
    float yaw = atan(to_player.x, to_player.z);

    // Rotation around Y axis
    float c = cos(yaw);
    float s = sin(yaw);

    mat4 rot_y = mat4(
        vec4( c, 0.0, -s, 0.0),
        vec4(0.0, 1.0,  0.0, 0.0),
        vec4( s, 0.0,  c, 0.0),
        vec4(0.0, 0.0, 0.0, 1.0)
    );

    // Extract the translation from MODEL_MATRIX (keep object position)
    mat4 translate = mat4(
        vec4(1.0, 0.0, 0.0, 0.0),
        vec4(0.0, 1.0, 0.0, 0.0),
        vec4(0.0, 0.0, 1.0, 0.0),
        vec4(obj_pos, 1.0)
    );

    // If your quad has its own scale baked in MODEL_MATRIX, you can preserve it:
    // mat4 scale_basis = MODEL_MATRIX * inverse(mat4(
    //     vec4(1,0,0,0), vec4(0,1,0,0), vec4(0,0,1,0), vec4(obj_pos,1)
    // ));
    // MODELVIEW_MATRIX = VIEW_MATRIX * translate * rot_y * scale_basis;

    // Simplest: overwrite orientation with yaw, keep position
    mat4 model_yaw = translate * rot_y;

    MODELVIEW_MATRIX = VIEW_MATRIX * model_yaw;
    MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}



void fragment() {
	vec2 current_tile = vec2(0,0);
	current_tile.x = data.r;
	current_tile.y = data.g;
	// Called for every pixel the material is visible on.
	//ANIMATION LEFTOVER CAN BE USED ONE DAY?
    // Control speed of switching
    float speed = 5.0; // 1 change per second
    // Step index increasing with time
   // int idx = int(floor(TIME * speed + float(id))) % nframe;
	//current_tile.x += float(idx);
	


	vec2 uv = UV;
	vec2 tile_size = 1.0 / vec2(tile_count);
	uv = UV * vec2(tile_size) + current_tile * vec2(tile_size);

	vec2 tex_size = vec2(textureSize(albedo_texture, 0));
	vec4 albedo_tex = texture(albedo_texture, uv);
	ALBEDO = albedo_tex.rgb* col.rgb;
	ALPHA *= albedo_tex.a * col.a;
	//ALPHA *= albedo.a * albedo_tex.a;

	//ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;



}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
