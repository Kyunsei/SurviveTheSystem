// Unified Life: one body rig (scripts/life/rig.gd) shaped per instance by the
// organism's developed body (see write_rig in shaders/life.comp).
//   INSTANCE_CUSTOM (24 exact bits each, see write_rig): (axis, symmetry, anchorage),
//   (appendage length, speed, segments, appendage pairs, action), (surfaces, feeding,
//   sensors), (carnivory, growth, protection).
//   The instance colour only reaches the fragment stage: rgb = body colour, a = hue.
// The model is 1 unit long along its body axis (the transform scales it to metres),
// facing -Z. The axis bends from horizontal (moves forward) to vertical (grows up);
// appendages become legs or branches, surfaces leaves or sails, feeding modules
// jaws at the head or a trap on top; anchored bodies grow roots and sway.
shader_type spatial;
render_mode cull_disabled;

varying flat float v_part;
varying flat float v_defence;
varying flat float v_gf;
varying flat float v_mouth;
varying flat float v_carni;
varying float v_shade;

vec3 unpack3(float f) {
	uint u = uint(round(f));
	return vec3(float(u & 255u), float((u >> 8u) & 255u), float((u >> 16u) & 255u)) / 255.0;
}

vec3 hue2rgb(float h, float s, float v) {
	vec3 k = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return v * mix(vec3(1.0), k, s);
}

// Outward direction of appendage slot k, side s: bilateral (left / right) blended
// with radial (spread around the axis).
vec3 outward(float k, float s, vec3 right, vec3 up2, float sym) {
	vec3 bil = right * (s > 0.5 ? 1.0 : -1.0);
	float th = s * PI + k * 2.39996;
	vec3 rad = right * cos(th) + up2 * sin(th);
	return normalize(mix(bil, rad, sym) + vec3(0.0, 0.001, 0.0));
}

void vertex() {
	vec3 c0 = unpack3(INSTANCE_CUSTOM.x); // axis, symmetry, anchorage
	uint p1 = uint(round(INSTANCE_CUSTOM.y));
	vec3 c2 = unpack3(INSTANCE_CUSTOM.z); // surfaces, feeding, sensors
	vec3 c3 = unpack3(INSTANCE_CUSTOM.w); // carnivory, growth, protection
	float applen = float(p1 & 255u) / 255.0;
	float speed = float((p1 >> 8u) & 127u) / 127.0;
	float nseg = 1.0 + float((p1 >> 15u) & 7u);
	float apps = float((p1 >> 18u) & 7u);
	float action = float((p1 >> 21u) & 7u);
	float ax = c0.x, sym = c0.y, anchor = c0.z;
	float photo = c2.x, mouth = c2.y, sense = c2.z;
	float gf = c3.y;
	float defence = c3.z;
	v_carni = c3.x;
	v_mouth = mouth;
	v_defence = defence;
	v_gf = gf;
	float part = UV2.x;
	float idx = UV2.y;
	float side = UV.x;
	v_part = part;
	v_shade = 1.0;

	// Body axis and frame.
	vec3 dir_a = normalize(mix(vec3(0.0, 0.12, -1.0), vec3(0.0, 1.0, 0.0), ax));
	vec3 right = vec3(1.0, 0.0, 0.0);
	vec3 up2 = cross(right, dir_a);
	float seg_l = 1.0 / nseg;
	float r = seg_l * mix(0.45, 0.16, ax) * (1.0 + 0.3 * defence);
	float leg_l = apps > 0.0 ? (0.15 + 0.45 * applen) : 0.0;
	float h0 = (1.0 - ax) * max(leg_l * 0.75, r);
	vec3 base = mix(vec3(0.0, h0, 0.0) - dir_a * 0.5, vec3(0.0), ax);
	float t = TIME;
	vec3 wobj = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// Anchored bodies sway in the wind, more towards the top.
	vec3 wind = vec3(sin(t * 1.3 + wobj.x * 0.3), 0.0, cos(t * 1.1 + wobj.z * 0.3)) * 0.03 * anchor;

	vec3 pos = vec3(0.0);
	vec3 nrm = NORMAL;
	bool show = true;
	vec3 V = VERTEX;

	if (part < 0.5) { // segment
		show = idx < nseg;
		float taper = 1.0 - 0.5 * ax * idx / nseg;
		vec3 c = base + dir_a * seg_l * (idx + 0.5) + wind * (idx + 0.5) * seg_l * 3.0;
		float rr = r * taper;
		pos = c + right * V.x * rr + up2 * V.z * rr + dir_a * V.y * seg_l * mix(0.62, 0.85, ax);
		nrm = normalize(right * V.x + up2 * V.z + dir_a * V.y);
	} else if (part < 1.5 || part < 2.5) { // appendage or surface
		bool is_leaf = part > 1.5;
		float k = idx;
		bool on_app = k < apps;
		float si = min(floor((k + 0.5) * nseg / max(apps, 1.0)), nseg - 1.0);
		if (!on_app) si = min(k, nseg - 1.0);
		vec3 c = base + dir_a * seg_l * (si + 0.5) + wind * (si + 0.5) * seg_l * 3.0;
		vec3 o = outward(k, side, right, up2, sym);
		// Legs reach down and out; branches reach up and out.
		vec3 leg_dir = normalize(o * 0.55 - vec3(0.0, 1.0, 0.0));
		vec3 branch_dir = normalize(o + vec3(0.0, 0.7, 0.0) + dir_a * 0.2);
		vec3 d = normalize(mix(leg_dir, branch_dir, ax));
		// Walking: muscular appendages swing with speed; phase alternates.
		float swing = sin(t * (5.0 + 8.0 * speed) + k * 1.7 + side * PI) * 0.6 * speed * (1.0 - anchor);
		d = normalize(d + dir_a * swing);
		float len = mix(leg_l, 0.2 + 0.6 * applen, ax) * (0.55 + 0.45 * gf);
		vec3 p0 = c + o * r * 0.8;
		vec3 tip = p0 + d * len + wind * len * 4.0;
		if (!is_leaf) {
			show = on_app;
			vec3 t1 = normalize(cross(d, vec3(0.0, 0.0, 1.0)) + vec3(0.001));
			vec3 t2 = normalize(cross(d, t1));
			float rr = seg_l * 0.12 * (0.6 + 0.4 * (1.0 - ax));
			vec3 knee = o * sin(PI * V.y) * len * 0.18 * (1.0 - ax);
			pos = p0 + d * len * V.y + knee + (t1 * V.x + t2 * V.z) * rr + wind * len * 4.0 * V.y;
			nrm = normalize(t1 * V.x + t2 * V.z);
		} else {
			show = photo > 0.0;
			// Leaves along the branches (tip, 70 %, 45 %) or around the segment;
			// sails stand on the back.
			float sub = UV.y;
			float along = 1.0 - 0.3 * sub - 0.05 * sub * sub;
			vec3 leaf_base = on_app ? mix(p0, tip, along) : c + o * r;
			float turn_l = (sub - 1.0) * 1.1;
			vec3 o2 = normalize(o * cos(turn_l) + cross(d, o) * sin(turn_l));
			vec3 leaf_dir = normalize(o2 * 0.7 + vec3(0.0, 0.45, 0.0) + vec3(0.0, sin(t * 2.0 + k + sub + wobj.x) * 0.08, 0.0));
			vec3 sail_base = c + up2 * r * 0.9 + dir_a * seg_l * (sub - 1.0) * 0.3;
			vec3 sail_dir = up2;
			float plantish = clamp(ax + anchor * 0.5, 0.0, 1.0);
			vec3 lb = mix(sail_base, leaf_base, plantish);
			vec3 ld = normalize(mix(sail_dir, leaf_dir, plantish));
			// Across the blade: along the body for sails, sideways to the branch for
			// leaves (never parallel to the leaf, so it cannot flip as leaves flutter).
			vec3 w = normalize(mix(dir_a, normalize(cross(ld, o2)), plantish));
			float size = (0.15 + 0.55 * photo) * (0.5 + 0.5 * gf) * mix(0.8, 1.2, plantish) * max(seg_l * 2.0, 0.4) * (1.0 - 0.15 * sub);
			pos = lb + ld * V.x * size + w * V.z * size * 0.55;
			nrm = normalize(cross(ld, w));
		}
	} else if (part < 3.5) { // jaw (or trap on top)
		show = mouth > 0.0;
		vec3 head = base + dir_a * seg_l * nseg + wind * 3.0;
		float open = 0.25 + 0.2 * v_carni + ((action < 1.5) ? 0.25 * sin(t * 9.0) : 0.0);
		vec3 jd = normalize(dir_a + up2 * (idx < 0.5 ? open : -open));
		float js = (0.08 + 0.25 * mouth) * max(seg_l * 2.0, 0.3) * (1.0 + 0.5 * v_carni);
		pos = head + right * V.x * js * 0.8 + jd * V.y * js + up2 * V.z * js * 0.3;
		nrm = up2;
	} else if (part < 4.5) { // eye
		show = sense > 0.0;
		vec3 head = base + dir_a * seg_l * (nseg - 0.35) + wind * 3.0;
		float er = r * (0.2 + 0.3 * sense);
		vec3 c = head + up2 * r * 0.55 + right * (side > 0.5 ? 1.0 : -1.0) * r * 0.55;
		pos = c + V * er;
		nrm = V;
	} else if (part < 5.5) { // root
		show = anchor > 0.3;
		vec3 o = vec3(cos(idx * PI * 0.5 + 0.4), 0.0, sin(idx * PI * 0.5 + 0.4));
		vec3 d = normalize(o * 0.8 - vec3(0.0, 0.5, 0.0));
		float len = (0.08 + 0.25 * anchor) * max(seg_l * 2.0, 0.4);
		vec3 p0 = base + dir_a * seg_l * 0.1;
		vec3 t1 = normalize(cross(d, vec3(0.0, 1.0, 0.0)));
		vec3 t2 = normalize(cross(d, t1));
		pos = p0 + d * len * V.y + (t1 * V.x + t2 * V.z) * r * 0.5;
		nrm = normalize(t1 * V.x + t2 * V.z);
	} else { // thorn
		show = defence > 0.2 && idx < nseg;
		vec3 c = base + dir_a * seg_l * (idx + 0.5) + wind * (idx + 0.5) * seg_l * 3.0;
		vec3 o = outward(idx + 0.5, side, right, up2, 0.5);
		float len = (defence - 0.2) * 0.35 * seg_l * 2.0;
		vec3 t1 = normalize(cross(o, dir_a) + vec3(0.001));
		pos = c + o * r + o * len * V.y + (t1 * V.x + dir_a * V.z) * r * 0.12 * (1.0 - V.y);
		nrm = o;
	}
	if (!show) pos = vec3(0.0);
	VERTEX = pos;
	NORMAL = normalize(nrm);
}

void fragment() {
	vec3 body = COLOR.rgb * (1.0 - 0.35 * v_defence);
	float hue = COLOR.a;
	vec3 leaf = hue2rgb(0.27 + (hue - 0.5) * 0.12, 0.7, 0.3 + 0.15 * v_gf);
	vec3 col = body;
	float rough = 0.8;
	if (v_part > 0.5 && v_part < 1.5) col = body * 0.85;                         // limbs / branches
	else if (v_part > 1.5 && v_part < 2.5) col = leaf;                            // leaves / sails
	else if (v_part > 2.5 && v_part < 3.5) {                                      // jaws / traps
		col = mix(vec3(0.85, 0.55, 0.45), vec3(0.8, 0.08, 0.06), v_carni);
		rough = 0.4;
	} else if (v_part > 3.5 && v_part < 4.5) { col = vec3(0.05); rough = 0.1; }  // eyes
	else if (v_part > 4.5 && v_part < 5.5) col = vec3(0.32, 0.22, 0.13);          // roots
	else if (v_part > 5.5) col = vec3(0.15, 0.12, 0.1);                           // thorns
	ALBEDO = col;
	ROUGHNESS = rough;
	// Two-sided parts (leaves, sails, jaws): light the side that faces the camera.
	if (!FRONT_FACING) NORMAL = -NORMAL;
}
