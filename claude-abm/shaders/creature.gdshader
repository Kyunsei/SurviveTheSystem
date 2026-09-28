// Agents in 3D. The mesh marks its parts in vertex colour alpha:
// 1.0 body, 0.75 horns, 0.5 eyes, 0.25 feet. Instance colour tints the body.
// INSTANCE_CUSTOM = (diet, action, speed, brain + 2 * selected).
shader_type spatial;
render_mode cull_back;

varying vec4 v_custom;
varying float v_part;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	v_part = COLOR.a;
	float diet = INSTANCE_CUSTOM.x;
	float speed = INSTANCE_CUSTOM.z;
	float moving = clamp(speed * 2.5, 0.0, 1.0);
	float phase = TIME * (6.0 + speed * 10.0) + float(INSTANCE_ID) * 1.7;
	if (COLOR.a > 0.7 && COLOR.a < 0.8) {
		// Horns grow with how carnivorous the agent is.
		VERTEX = mix(vec3(0.0, 0.66, -0.42), VERTEX, smoothstep(0.3, 0.8, diet));
	} else if (COLOR.a > 0.2 && COLOR.a < 0.3) {
		VERTEX.z += sin(phase + sign(VERTEX.x) * sign(VERTEX.z) * 1.5708) * 0.12 * moving;
	}
	VERTEX.y += abs(sin(phase)) * 0.1 * moving + sin(TIME * 2.0 + float(INSTANCE_ID)) * 0.01;
	if (abs(INSTANCE_CUSTOM.y - 7.0) < 0.5) VERTEX.y *= 0.55; // hiding: pressed low
}

void fragment() {
	vec3 col = COLOR.rgb;
	ROUGHNESS = 0.65;
	if (v_part > 0.7 && v_part < 0.8) {
		col = vec3(0.85, 0.8, 0.7);
	} else if (v_part > 0.4 && v_part < 0.6) {
		col = vec3(0.02);
		ROUGHNESS = 0.1;
		if (abs(v_custom.y - 1.0) < 0.5) EMISSION = vec3(3.0, 0.15, 0.05); // hunting: red eyes
	} else if (v_part < 0.3) {
		col *= 0.45;
	}
	ALBEDO = col;
	if (v_custom.w >= 1.5) { // aimed at / followed: glowing rim
		float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
		EMISSION += vec3(1.0, 0.85, 0.3) * rim * 2.5;
	}
}
