// Terrain around the player: a flat grid that follows the player, displaced by
// the height map. Colours come from the live simulation field (plants, carrion).
shader_type spatial;
render_mode cull_back;

uniform sampler2D height_tex : filter_linear, repeat_enable;
uniform sampler2D field_tex : filter_linear, repeat_enable; // rgb = 2D view colours, a = plants
uniform float world_size = 2048.0;

varying vec3 wpos;
varying vec3 wnormal;

void vertex() {
	vec2 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec2 uv = w / world_size;
	float h = textureLod(height_tex, uv, 0.0).r;
	VERTEX.y = h;
	float e = 1.0 / world_size;
	float hx = textureLod(height_tex, uv + vec2(e, 0.0), 0.0).r - textureLod(height_tex, uv - vec2(e, 0.0), 0.0).r;
	float hz = textureLod(height_tex, uv + vec2(0.0, e), 0.0).r - textureLod(height_tex, uv - vec2(0.0, e), 0.0).r;
	NORMAL = normalize(vec3(-hx, 2.0, -hz));
	wpos = vec3(w.x, h, w.y);
	wnormal = NORMAL;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 uv = wpos.xz / world_size;
	vec4 field = texture(field_tex, uv);
	// field.rgb is the local plant lineage colour (purple = defended, red = carrion),
	// field.a the plant density.
	vec3 soil = vec3(0.27, 0.21, 0.14);

	vec3 sand = vec3(0.62, 0.56, 0.41);
	vec3 rock = vec3(0.40, 0.38, 0.36);
	float n = (vnoise(wpos.xz * 0.35) + vnoise(wpos.xz * 1.7) * 0.5) * 0.06 - 0.045;
	vec3 col = mix(soil, field.rgb * 0.85, smoothstep(0.02, 0.5, field.a)) + n;
	col = mix(sand, col, smoothstep(0.2, 1.2, wpos.y));                  // beaches
	col = mix(col, rock, smoothstep(0.35, 0.6, 1.0 - wnormal.y));       // cliffs
	if (wpos.y < 0.0) col = mix(sand * 0.7, vec3(0.12, 0.16, 0.18), clamp(-wpos.y / 5.0, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
