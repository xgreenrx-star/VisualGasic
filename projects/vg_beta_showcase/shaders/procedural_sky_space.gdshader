shader_type sky;

// Deep space sky — stars + nebula. Optional warp streak multiplier for carrier intro.

uniform float warp : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash3(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += noise(p) * amp;
		p *= 2.05;
		amp *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);

	vec3 col = mix(vec3(0.001, 0.002, 0.012), vec3(0.025, 0.045, 0.13), dir.y * 0.5 + 0.5);

	float neb = fbm(dir.xz * 2.4 + vec2(TIME * 0.008, 0.0));
	col += vec3(0.07, 0.04, 0.16) * neb * 0.4;

	float stars_a = hash3(floor(dir * 520.0));
	float stars_b = hash3(floor(dir * 880.0 + 17.0));
	float stars = step(0.9982, stars_a) + step(0.9990, stars_b) * 0.55;
	col += vec3(0.85, 0.92, 1.0) * stars * 0.85;

	// Warp streaks — radial smear when warp > 0
	if (warp > 0.001) {
		float streak = pow(max(0.0, 1.0 - abs(dir.y)), 2.0);
		float lines = step(0.9975, hash3(floor(dir * mix(520.0, 48.0, warp))));
		col += vec3(0.6, 0.85, 1.0) * lines * streak * warp * 1.6;
		col = mix(col, vec3(0.85, 0.95, 1.0), warp * streak * 0.35);
	}

	COLOR = col;
}
