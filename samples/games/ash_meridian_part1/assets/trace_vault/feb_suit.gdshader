shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

// FEB Trace suit: glossy near-black bodysuit with thin emissive circuit lines.
// Lines are drawn in figure space (+Y up, -Z forward), so meshes must be placed so
// their object space equals the FEB figure frame (pieces under pivots are offset back).
// part: 0 = torso/legs, 1 = arm, 2 = head (skin face + suited neck), 3 = helmet shell.
uniform int part = 0;
uniform vec4 suit_color : source_color = vec4(0.035, 0.045, 0.06, 1.0);
uniform vec4 glove_color : source_color = vec4(0.015, 0.02, 0.028, 1.0);
uniform vec4 skin_color : source_color = vec4(0.72, 0.55, 0.46, 1.0);
uniform vec4 line_color : source_color = vec4(0.25, 0.92, 1.0, 1.0);
uniform float line_energy = 3.2;
uniform float rim_energy = 0.35;
uniform float power = 1.0;
uniform float neck_top = 1.665;
uniform float wrist_y = 0.935;
uniform float boot_y = 0.3;
uniform float brow_y = 1.79;
uniform float helmet_back_z = -0.031;

varying vec3 p;
varying vec3 nrm;

void vertex() {
	p = VERTEX;
	nrm = NORMAL;
}

float band(float d, float w) {
	float aa = max(fwidth(d), 1e-5) * 1.2;
	return 1.0 - smoothstep(w, w + aa, abs(d));
}

float seg(vec2 q, vec2 a, vec2 b, float w) {
	vec2 pa = q - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return band(length(pa - ba * h), w);
}

void fragment() {
	vec3 n = normalize(nrm);
	float front = smoothstep(0.15, 0.4, -n.z);
	float lines = 0.0;
	vec3 base = suit_color.rgb;
	float rough = 0.3;
	bool skin = false;
	float ax = abs(p.x);

	if (part == 0 || part == 1) {
		// Silhouette seams: thin lines where the surface turns side-on.
		lines = max(lines, band(n.z, 0.045) * step(0.8, abs(n.x)) * step(0.12, p.y) * (1.0 - step(1.53, p.y)));
	}
	if (part == 0) {
		lines = max(lines, band(p.y - 1.02, 0.006));
		lines = max(lines, band(p.y - 1.545, 0.005));
		lines = max(lines, band(p.y - boot_y, 0.005) * step(p.y, 0.5));
		lines = max(lines, band(p.x, 0.0035) * front * step(1.04, p.y) * step(p.y, 1.2));
		lines = max(lines, seg(vec2(ax, p.y), vec2(0.165, 1.49), vec2(0.0, 1.21), 0.0035) * front);
		lines = max(lines, seg(vec2(ax, p.y), vec2(0.045, 1.13), vec2(0.13, 1.06), 0.003) * front);
		lines = max(lines, band(ax - 0.1, 0.0035) * front * step(0.34, p.y) * step(p.y, 0.92));
		if (p.y < boot_y) base = glove_color.rgb;
	}
	if (part == 1) {
		lines = max(lines, band(p.y - wrist_y, 0.005));
		lines = max(lines, band(p.y - 1.18, 0.004));
		if (p.y < wrist_y) {
			base = glove_color.rgb;
			lines *= step(wrist_y - 0.02, p.y);
		}
	}
	if (part == 2) {
		// Scalp under the helmet stays suit-dark, so gaps in the shell's cut edge never show skin.
		bool scalp = p.y > brow_y - 0.002 || (p.z > helmet_back_z - 0.002 && p.y > neck_top + 0.03);
		if (p.y > neck_top && !scalp) {
			skin = true;
		} else if (scalp) {
			lines = max(lines, band(p.y - (brow_y + 0.004), 0.004) * step(p.z, helmet_back_z));
		} else {
			lines = max(lines, band(p.y - (neck_top - 0.006), 0.004));
		}
	}
	if (part == 3) {
		// Clean visor edge: the shell is cut on faces, so trim it to the brow and ear line.
		if (p.y < brow_y + 0.009 && p.z < helmet_back_z + 0.004) discard;
		lines = max(lines, band(p.x, 0.0028) * step(0.2, n.y));
				lines = max(lines, band(p.z - helmet_back_z, 0.003) * step(p.y, brow_y));
		lines = max(lines, band(p.y - (brow_y + 0.04), 0.003) * step(0.0, -n.z));
		rough = 0.22;
	}

	if (skin) {
		ALBEDO = skin_color.rgb;
		ROUGHNESS = 0.62;
		SPECULAR = 0.35;
	} else {
		ALBEDO = mix(base, line_color.rgb * 0.6, lines);
		ROUGHNESS = rough;
		METALLIC = 0.25;
		float rim = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 3.0);
		EMISSION = line_color.rgb * (lines * line_energy * power + rim * rim_energy * power * 0.4);
	}
}
