// Lake surface at y = 0 that follows the player. Depth comes from the height map.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_always;

uniform sampler2D height_tex : filter_linear, repeat_enable;
uniform float world_size = 2048.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float depth = -texture(height_tex, wpos.xz / world_size).r;
	if (depth < -0.05) discard; // dry land pokes through
	vec2 p = wpos.xz;
	float t = TIME;
	vec3 n = normalize(vec3(
			sin(p.x * 0.35 + t * 1.3) * 0.06 + sin(p.y * 0.9 + p.x * 0.4 + t * 2.1) * 0.03,
			1.0,
			cos(p.y * 0.3 + t * 1.1) * 0.06 + cos(p.x * 0.8 - p.y * 0.5 + t * 1.7) * 0.03));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float d = clamp(depth / 6.0, 0.0, 1.0);
	ALBEDO = mix(vec3(0.10, 0.34, 0.38), vec3(0.02, 0.08, 0.20), d);
	ALPHA = mix(0.45, 0.92, d);
	ROUGHNESS = 0.06;
	SPECULAR = 0.7;
}
