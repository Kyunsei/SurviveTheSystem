shader_type spatial;
// Fake clouds for the little-planet world.
//  - A flat sheet at cloud height, bent down with distance exactly like the world
//    (drop = d² / (2 × planet_radius)), so it curves over the planet and dips below the horizon.
//  - Procedural noise in WORLD coordinates, periodic on the world size: clouds stay put
//    when the camera moves and tile seamlessly across the wrap-around borders.
//  - A clear hole above the player so the top-down views are never blocked.
// Driven by CloudLayer.gd (center, world size, wind drift).
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

global uniform float planet_radius;              // the Shader Global you already set (0 = flat)

uniform vec3 wrap_center = vec3(0.0);            // camera.get_wrap_center(), set by the script
uniform vec2 world_size = vec2(512.0);           // WorldWrap.size (x, z), set by the script
uniform vec2 cloud_offset = vec2(0.0);           // wind drift, set by the script

group_uniforms shape;
uniform float cloud_scale = 60.0;                // size of one cloud (world units)
uniform float coverage : hint_range(0.0, 1.0) = 0.45;   // 0 = clear sky, 1 = overcast
uniform float softness : hint_range(0.01, 0.5) = 0.12;  // edge blur
uniform int octaves : hint_range(1, 6) = 4;      // detail levels (cost)
uniform float detail : hint_range(0.0, 1.0) = 0.5;      // strength of the small details

group_uniforms look;
uniform vec4 light_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 shade_color : source_color = vec4(0.60, 0.64, 0.74, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.85;
uniform vec2 sun_dir = vec2(0.6, 0.4);           // on the ground plane (x, z)
uniform float self_shadow : hint_range(0.0, 2.0) = 1.0; // darker side away from the sun

group_uniforms fade;
uniform float clear_radius = 18.0;               // hole above the player (0 = none)
uniform float fade_start = 130.0;                // far fade (set by the script from its radius)
uniform float fade_end = 220.0;

varying vec2 v_xz;          // world position (before bending): where the noise is read
varying float v_dist;       // horizontal distance to the view center


float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Value noise that repeats every `period` cells (seamless on the wrapped world)
float vnoise(vec2 p, vec2 period) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(mod(i, period));
	float b = hash(mod(i + vec2(1.0, 0.0), period));
	float c = hash(mod(i + vec2(0.0, 1.0), period));
	float d = hash(mod(i + vec2(1.0, 1.0), period));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p, vec2 period) {
	float sum = 0.0;
	float amp = 0.5;
	float norm = 0.0;
	for (int k = 0; k < 6; k++) {
		if (k >= octaves) { break; }
		sum += vnoise(p, period) * amp;
		norm += amp;
		p *= 2.0;
		period *= 2.0;            // each octave still tiles on the world size
		amp *= detail;
	}
	return sum / max(norm, 1e-4);
}

// 0 = clear sky, 1 = thick cloud, at a world position
float density(vec2 xz) {
	vec2 period = max(round(world_size / cloud_scale), vec2(1.0));   // whole cells per world
	vec2 p = (xz + cloud_offset) / world_size * period;
	float n = fbm(p, period);
	float edge = 1.0 - coverage;
	return smoothstep(edge - softness, edge + softness, n);
}


void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_xz = wp.xz;
	v_dist = length(wp.xz - wrap_center.xz);
	// Same bend as the world. The node is only moved (no rotation / scale), so the
	// world-space drop is also the local one.
	if (planet_radius > 0.0) {
		VERTEX.y -= v_dist * v_dist / (2.0 * planet_radius);
	}
}


void fragment() {
	float dens = density(v_xz);
	if (dens < 0.002) { discard; }

	// Fake lighting: the side facing away from the sun is darker
	vec2 toward_sun = normalize(sun_dir + vec2(1e-5)) * cloud_scale * 0.15;
	float occl = clamp(density(v_xz + toward_sun) - dens * 0.6, 0.0, 1.0);
	vec3 col = mix(light_color.rgb, shade_color.rgb, clamp(occl * self_shadow, 0.0, 1.0));
	col = mix(col, shade_color.rgb, (1.0 - dens) * 0.25);   // thin edges a bit greyer

	float a = dens * opacity;
	a *= 1.0 - smoothstep(fade_start, fade_end, v_dist);            // far: fade out
	if (clear_radius > 0.0) {
		a *= smoothstep(clear_radius, clear_radius * 2.0, v_dist);   // near: hole above the player
	}

	ALBEDO = col;
	ALPHA = a;
}