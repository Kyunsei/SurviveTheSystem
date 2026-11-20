shader_type spatial;
// Multiply blend: order-independent, so overlapping shadows never need sorting
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled, shadows_disabled;

// Same agent_data texture as the sprite shader (test3d.gdshader)
uniform sampler2D agent_data : filter_nearest, repeat_disable;
uniform int tex_width = 1024;
uniform float world_height = 48.0;

uniform float ground_y = 0.0;                          // height of the ground
uniform vec2 sun_offset = vec2(0.3, 0.2);              // shadow shift (x, z) per unit of height
uniform float strength : hint_range(0.0, 1.0) = 0.45;  // darkness at the center
uniform float radius_scale = 0.5;                      // shadow radius relative to agent size
uniform float fade_height = 10.0;                      // no shadow above this height

varying float v_strength;

uniform vec3 world_size = vec3(100.0);
uniform vec3 wrap_axes = vec3(0.0);     // 1.0 on axes that wrap

// The copy of p closest to ref (shortest way through the borders)
vec3 nearest_image(vec3 p, vec3 ref) {
	vec3 d = p - ref;
	d -= wrap_axes * world_size * round(d / max(world_size, vec3(1e-6)));
	return ref + d;
}

void vertex() {
	ivec2 px = ivec2(INSTANCE_ID % tex_width, INSTANCE_ID / tex_width);
	vec4 d = texelFetch(agent_data, px, 0);

	int v = int(d.w + 0.5);
	int state = v & 3;
	float size       = float((v >> 6) & 255) * 0.1;      // 8 bits: 0 to 25.5

	int b = int(d.z + 0.5);
	float y = float(b >> 12) / 4095.0 * world_height;

	if (state == 0) {
		VERTEX = vec3(0.0);                            // free slot: not drawn
		v_strength = 0.0;
	} else {
		float h = max(y - ground_y, 0.0);
		v_strength = clamp(1.0 - h / fade_height, 0.0, 1.0);
		vec2 c = vec2(d.x, d.y) + sun_offset * h;      // shift with the sun direction
		vec3 cam_pos = MAIN_CAM_INV_VIEW_MATRIX[3].xyz;
		vec3 spot = nearest_image(MODEL_MATRIX[3].xyz + vec3(c.x, ground_y + 0.01, c.y), cam_pos);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
				vec4(1.0, 0.0, 0.0, 0.0),
				vec4(0.0, 0.0, 1.0, 0.0),
				vec4(0.0, 1.0, 0.0, 0.0),
				vec4(spot, 1.0));
		// Lay the quad flat on the ground: local x -> world x, local y -> world z

		VERTEX *= size * radius_scale * 2.0;
	}
}


void fragment() {
	float r = length(UV - 0.5) * 2.0;                  // 0 at the center, 1 at the edge
	float a = (1.0 - smoothstep(0.3, 1.0, r)) * strength * v_strength;
	ALBEDO = vec3(1.0 - a);                            // multiplied with what's behind
}
