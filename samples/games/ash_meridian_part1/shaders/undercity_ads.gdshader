shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

// Procedural Narcean advertising for the B13 undercity screens. Each screen gets
// its own seed: palette, style_k, glyph rows and a scrolling ticker. power = 0 is a
// dead panel with faint residual static; power = 1 runs the ad loop.
uniform float power = 0.0;
uniform float seed = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.13) * 43758.5453);
}

float hash1(float n) {
	return fract(sin(n * 91.7 + seed * 3.31) * 15731.743);
}

vec3 palette(float k) {
	vec3 a = vec3(0.55, 0.35, 0.65);
	vec3 b = vec3(0.45, 0.45, 0.35);
	vec3 d = vec3(hash1(1.0), hash1(2.0) + 0.33, hash1(3.0) + 0.67);
	return a + b * cos(6.28318 * (k + d));
}

// A stroke glyph built from the same six-stroke family as the wall plaques.
float glyph(vec2 p, float id) {
	if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0) return 0.0;
	float m = 0.0;
	float w = 0.09;
	float bits = floor(hash1(id) * 63.0) + 1.0;
	if (mod(bits, 2.0) >= 1.0) m = max(m, step(abs(p.y - (0.15 + abs(p.x - 0.5) * 0.4)), w));
	if (mod(floor(bits / 2.0), 2.0) >= 1.0) m = max(m, step(abs(p.y - (0.85 - abs(p.x - 0.5) * 0.4)), w));
	if (mod(floor(bits / 4.0), 2.0) >= 1.0) m = max(m, step(abs(p.x - 0.08), w) * step(0.1, p.y) * step(p.y, 0.9));
	if (mod(floor(bits / 8.0), 2.0) >= 1.0) m = max(m, step(abs(p.x - 0.92), w) * step(0.1, p.y) * step(p.y, 0.9));
	if (mod(floor(bits / 16.0), 2.0) >= 1.0) m = max(m, step(abs(p.y - 0.5), w) * step(0.2, p.x) * step(p.x, 0.8));
	if (mod(floor(bits / 32.0), 2.0) >= 1.0) m = max(m, step(abs(p.x - 0.5), w));
	return m;
}

float glyph_row(vec2 uv, float count, float row_id) {
	vec2 g = vec2(uv.x * count, uv.y);
	float cell = floor(g.x);
	vec2 f = vec2(fract(g.x) * 1.25 - 0.12, g.y);
	return glyph(f, cell + row_id * 37.0 + floor(seed));
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float t = TIME;
	float scene_len = 7.0 + hash1(9.0) * 5.0;
	float scene = floor((t + hash1(4.0) * 20.0) / scene_len);
	float local = fract((t + hash1(4.0) * 20.0) / scene_len);
	vec3 c1 = palette(hash1(scene + 11.0));
	vec3 c2 = palette(hash1(scene + 23.0) + 0.5);
	float style_k = floor(hash1(scene + 31.0) * 3.0);
	vec3 col = mix(c1 * 0.18, c2 * 0.3, uv.y);
	// Moving light bands behind the product.
	col += c2 * 0.25 * smoothstep(0.9, 1.0, sin(uv.x * 9.0 - uv.y * 4.0 + t * 1.6) * 0.5 + 0.5);
	if (style_k < 1.0) {
		// Hero object: a pulsing ringed sphere with a headline.
		vec2 q = (uv - vec2(0.33, 0.55)) * vec2(1.6, 1.0);
		float r = length(q);
		float pulse = 0.28 + 0.03 * sin(t * 3.0);
		col += c1 * smoothstep(pulse, pulse - 0.03, r) * (0.6 + 0.4 * sin(q.y * 30.0 + t * 4.0));
		col += c2 * smoothstep(0.02, 0.0, abs(r - pulse - 0.08 - 0.02 * sin(t * 2.0)));
		col += vec3(1.0) * 0.9 * glyph_row((uv - vec2(0.62, 0.62)) / vec2(0.34, 0.2), 4.0, scene);
		col += c2 * glyph_row((uv - vec2(0.62, 0.42)) / vec2(0.3, 0.1), 6.0, scene + 3.0);
	} else if (style_k < 2.0) {
		// Giant headline that wipes in, with a price block.
		float wipe = smoothstep(0.0, 0.2, local);
		float head = glyph_row((uv - vec2(0.06, 0.45)) / vec2(0.88, 0.38), 5.0, scene + 5.0);
		col += mix(c1, vec3(1.0), 0.4) * head * step(uv.x, wipe);
		col += c2 * 0.8 * step(abs(uv.y - 0.3), 0.06) * step(0.1, uv.x) * step(uv.x, 0.9 * wipe);
		col += vec3(1.0) * glyph_row((uv - vec2(0.15, 0.25)) / vec2(0.5, 0.1), 7.0, scene + 7.0);
	} else {
		// Product grid of tumbling shapes.
		vec2 g = uv * vec2(4.0, 3.0);
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		float a = t * (0.5 + hash(id)) + hash(id + 3.0) * 6.28;
		f = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a))) * f;
		float shape = max(abs(f.x), abs(f.y));
		col += palette(hash(id) + scene * 0.1) * smoothstep(0.24, 0.2, shape) * smoothstep(0.1, 0.16, shape);
		col += vec3(1.0) * 0.5 * glyph((fract(g) - vec2(0.3, 0.05)) / vec2(0.4, 0.22), id.x + id.y * 7.0 + scene);
	}
	// Ticker along the bottom.
	float tick_band = step(uv.y, 0.12);
	vec2 tuv = vec2(fract(uv.x * 1.0 + t * 0.12), uv.y / 0.12);
	col = mix(col, c2 * 0.15, tick_band * 0.8);
	col += vec3(1.0, 0.9, 0.5) * tick_band * glyph_row(vec2(tuv.x, tuv.y * 1.2 - 0.1), 14.0, floor(t * 0.12 + uv.x) + 50.0);
	// Frame glow, scene-cut flash and CRT scanlines.
	float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	col += c1 * smoothstep(0.03, 0.0, edge);
	col += vec3(0.6) * smoothstep(0.04, 0.0, local) ;
	col *= 0.82 + 0.18 * sin(FRAGCOORD.y * 2.2);
	float noise = hash(floor(uv * vec2(160.0, 90.0)) + floor(t * 24.0));
	col = mix(col, vec3(noise) * 0.6, 0.06);
	vec3 dead = vec3(noise) * 0.035 * step(0.97, hash1(floor(t * 3.0)) + noise * 0.05) + vec3(0.004, 0.006, 0.012);
	ALBEDO = mix(dead, col * 1.6, clamp(power, 0.0, 1.0));
}
