// Individual plants (grass, flowers, bushes, trees), placed by the GPU simulation.
// Vertex colour alpha tags parts: 1.0 leaves / broadleaf crown, 0.75 conifer crown,
// 0.5 petals, 0.4 fruit, 0.25 trunk and stems. Instance colour = leaf colour.
// INSTANCE_CUSTOM = (flowering, ripe fruit 0..1, conifer, petal hue).
shader_type spatial;
render_mode cull_disabled;

varying float v_part;
varying vec4 v_custom;

vec3 hue2rgb(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void vertex() {
	v_part = COLOR.a;
	v_custom = INSTANCE_CUSTOM;
	bool conifer = INSTANCE_CUSTOM.z > 0.5;
	bool hide = (COLOR.a > 0.9 && conifer)                          // broadleaf crown on a conifer
			|| (COLOR.a > 0.7 && COLOR.a < 0.8 && !conifer)          // conifer crown on a broadleaf
			|| (COLOR.a > 0.45 && COLOR.a < 0.55 && INSTANCE_CUSTOM.x < 0.5)  // petals out of bloom
			|| (COLOR.a > 0.35 && COLOR.a < 0.45 && INSTANCE_CUSTOM.y <= 0.0); // no ripe fruit
	if (hide) VERTEX = vec3(0.0);
	// Wind: more at the top.
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	VERTEX.x += sin(TIME * 1.6 + w.x * 0.3 + w.z * 0.2) * 0.03 * VERTEX.y;
}

void fragment() {
	vec3 col = COLOR.rgb;
	ROUGHNESS = 0.85;
	if (v_part < 0.3) {
		col = vec3(0.32, 0.23, 0.14);                               // trunk, stems
	} else if (v_part < 0.45) {
		col = vec3(0.75, 0.12, 0.10);                               // fruit
		ROUGHNESS = 0.4;
	} else if (v_part < 0.55) {
		col = mix(hue2rgb(v_custom.w), vec3(1.0), 0.15);            // petals
	}
	ALBEDO = col;
}
