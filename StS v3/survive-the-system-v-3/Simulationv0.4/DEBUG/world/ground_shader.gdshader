shader_type spatial;
// Endless ground for the control mode (used by wrap_ground.gd).
// - Texture read in WORLD coordinates: it never slides when the plane follows the camera.
// - Repeats every tile_size (one GridMap tile), or once over the whole world (tile_size = 0).
// - Wrapped onto the little planet's sphere and cut to a circle (needs a subdivided plane).
//
// Needs two Shader Globals (Project Settings > Globals > Shader Globals):
//   wrap_center   vec3    (set by FlyCamera)
//   planet_radius float   (set by PlayerController, 0 = flat)

uniform sampler2D ground_texture : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 world_size = vec3(100.0);
// World units covered by one copy of the texture:
//   > 0: the texture is ONE tile, repeated every tile_size (e.g. the GridMap cell size)
//   = 0: the texture is the WHOLE world, repeated every world size
uniform float tile_size = 1.0;

// Optional grid lines (grid_cell > 0), e.g. 1.0 for 1 m tiles
uniform float grid_cell = 0.0;
uniform vec4 grid_color : source_color = vec4(0.0, 0.0, 0.0, 0.25);
uniform float grid_width = 0.03;

// Optional line on the world borders (alpha > 0 to show where the world repeats)
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float border_width = 0.1;

// Little planet
global uniform vec3 wrap_center;
global uniform float planet_radius;

varying vec3 world_pos;


// 1 on a line, 0 between lines (lines every `cell` units, `width` wide)
float line_mask(vec2 p, float cell, float width) {
	vec2 g = abs(fract(p / cell + 0.5) - 0.5) * cell;   // distance to the nearest line
	return 1.0 - smoothstep(0.0, width, min(g.x, g.y));
}


// Little planet (same as the sprite shader): sphere touching the ground at wrap_center
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

float planet_limit() {
	return min(min(world_size.x, world_size.z) * 0.5, PI * planet_radius * 0.97);
}


void vertex() {
	// Flat position: used for the texture and the grid, so they stay aligned
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Wrap the ground onto the ball (the plane has no rotation / scale)
	vec3 up;
	VERTEX = curve(world_pos, up) - MODEL_MATRIX[3].xyz;
	NORMAL = up;
}


void fragment() {
	// Outside the planet's circle: nothing (the ball's edge against the sky)
	if (planet_radius > 0.0 && distance(world_pos.xz, wrap_center.xz) > planet_limit()) {
		discard;
	}

	// Everything repeats EXACTLY every world size, so crossing a border (where the camera
	// and this plane jump by one world size) changes nothing on screen.
	// The tile and the grid are stretched very slightly so a whole number fits the world.
	vec2 uv;
	if (tile_size > 0.0) {
		vec2 tiles = max(round(world_size.xz / tile_size), vec2(1.0));
		uv = world_pos.xz * tiles / world_size.xz;          // one tile, repeated
	} else {
		uv = world_pos.xz / world_size.xz;                  // the whole world, repeated
	}
	vec3 col = texture(ground_texture, uv).rgb * tint.rgb;

	if (grid_cell > 0.0) {
		vec2 cells = max(round(world_size.xz / grid_cell), vec2(1.0));
		vec2 g = abs(fract(world_pos.xz * cells / world_size.xz + 0.5) - 0.5) * (world_size.xz / cells);
		float m = 1.0 - smoothstep(0.0, grid_width, min(g.x, g.y));
		col = mix(col, grid_color.rgb, m * grid_color.a);
	}
	if (border_color.a > 0.0) {
		vec2 b = abs(fract(world_pos.xz / world_size.xz + 0.5) - 0.5) * world_size.xz;
		float m = 1.0 - smoothstep(0.0, border_width, min(b.x, b.y));
		col = mix(col, border_color.rgb, m * border_color.a);
	}
	ALBEDO = col;
}