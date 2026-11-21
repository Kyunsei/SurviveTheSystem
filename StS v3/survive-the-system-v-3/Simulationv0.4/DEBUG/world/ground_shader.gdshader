shader_type spatial;
// Ground for a wrapping world: the texture repeats every world size,
// so the plane can follow the camera and look endless.

// One texture for the WHOLE world (e.g. 1 pixel per cell). Repeats beyond the borders.
uniform sampler2D ground_texture : source_color, filter_nearest, repeat_enable;
uniform vec3 world_size = vec3(100.0);
uniform vec4 tint : source_color = vec4(1.0);

// Optional grid lines (grid_cell > 0), e.g. 1.0 for 1 m tiles
uniform float grid_cell = 0.0;
uniform vec4 grid_color : source_color = vec4(0.0, 0.0, 0.0, 0.25);
uniform float grid_width = 0.03;

// Optional line on the world borders (alpha > 0 to show where the world repeats)
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float border_width = 0.1;

varying vec3 world_pos;


float line_mask(vec2 p, float cell, float width) {
	vec2 g = abs(fract(p / cell + 0.5) - 0.5) * cell;   // distance to the nearest line
	return 1.0 - smoothstep(0.0, width, min(g.x, g.y));
}


void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	vec2 uv = world_pos.xz / world_size.xz;               // repeat_enable does the wrapping
	vec3 col = texture(ground_texture, uv).rgb * tint.rgb;

	if (grid_cell > 0.0) {
		col = mix(col, grid_color.rgb, line_mask(world_pos.xz, grid_cell, grid_width) * grid_color.a);
	}
	if (border_color.a > 0.0) {
		vec2 b = abs(fract(world_pos.xz / world_size.xz + 0.5) - 0.5) * world_size.xz;
		float m = 1.0 - smoothstep(0.0, border_width, min(b.x, b.y));
		col = mix(col, border_color.rgb, m * border_color.a);
	}
	ALBEDO = col;
}
