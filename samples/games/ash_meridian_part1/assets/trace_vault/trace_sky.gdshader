shader_type sky;

// Night sky over the void: star field, nebula band, two moons with phases.
uniform vec3 zenith_color : source_color = vec3(0.004, 0.006, 0.02);
uniform vec3 horizon_color : source_color = vec3(0.05, 0.035, 0.09);
uniform vec3 abyss_color : source_color = vec3(0.012, 0.01, 0.026);
uniform vec3 nebula_color : source_color = vec3(0.32, 0.12, 0.42);
uniform vec3 nebula_edge : source_color = vec3(0.08, 0.38, 0.5);
uniform vec3 moon_a_dir = vec3(-0.42, 0.34, -0.84);
uniform vec3 moon_b_dir = vec3(0.71, 0.2, -0.67);
uniform float moon_a_size = 0.075;
uniform float moon_b_size = 0.032;
uniform float star_density = 0.006;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x),
			mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x),
			mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise3(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

float stars(vec3 d, float scale, float density) {
	vec3 p = d * scale;
	vec3 cell = floor(p);
	float r = hash13(cell);
	if (r > density) {
		return 0.0;
	}
	vec3 centre = cell + 0.5 + (vec3(hash13(cell + 7.1), hash13(cell + 3.7), hash13(cell + 1.3)) - 0.5) * 0.6;
	float dist = length(p - centre);
	float twinkle = 0.75 + 0.25 * sin(TIME * (1.5 + r * 900.0) + r * 60.0);
	// Keep a roughly constant on-screen size so dense layers do not go sub-pixel.
	float radius = clamp(0.0012 * scale, 0.14, 0.45);
	return smoothstep(radius, 0.0, dist) * twinkle * (0.4 + 0.6 * hash13(cell + 11.0));
}

vec3 moon(vec3 d, vec3 dir, float size, vec3 tint, vec3 light, float seed) {
	vec3 m = normalize(dir);
	float c = dot(d, m);
	float edge = cos(size);
	vec3 col = vec3(0.0);
	float halo = exp(-max(0.0, acos(clamp(c, -1.0, 1.0)) - size) * 18.0);
	col += tint * halo * 0.22;
	if (c > edge) {
		vec3 t = normalize(cross(m, vec3(0.0, 1.0, 0.0)));
		vec3 b = cross(t, m);
		vec2 q = vec2(dot(d, t), dot(d, b)) / sin(size);
		float z = sqrt(max(0.0, 1.0 - dot(q, q)));
		vec3 n = normalize(vec3(q, z));
		float lit = smoothstep(-0.05, 0.25, dot(n, normalize(light)));
		float craters = fbm(vec3(q * 5.0, seed)) * 0.55 + fbm(vec3(q * 17.0, seed + 4.0)) * 0.25;
		float limb = smoothstep(1.0, 0.82, length(q));
		vec3 surface = tint * (0.55 + craters) * limb;
		col = mix(col, surface * (0.06 + lit * 1.35), smoothstep(edge, edge + 0.00025, c));
	}
	return col;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = mix(horizon_color, zenith_color, smoothstep(0.0, 0.55, h));
	col = mix(col, abyss_color, smoothstep(0.0, -0.25, h));

	// Nebula band along a tilted great circle.
	vec3 band_axis = normalize(vec3(0.25, 0.55, 0.8));
	float band = exp(-pow(dot(d, band_axis) * 3.2, 2.0));
	float cloud = fbm(d * 3.4 + vec3(0.0, TIME * 0.004, 0.0));
	float wisps = fbm(d * 9.0 + 2.7);
	vec3 neb = mix(nebula_color, nebula_edge, smoothstep(0.35, 0.8, wisps));
	float above = smoothstep(-0.12, 0.12, h);
	col += neb * band * smoothstep(0.32, 0.85, cloud) * 0.55 * above;

	// Four star depths: rare bright HDR stars that bloom, two mid layers, and a
	// fine dust layer packed into the nebula band (milky-way look).
	float veil = above * (1.0 - band * smoothstep(0.45, 0.8, cloud) * 0.5);
	float bright = stars(d, 70.0, 0.012);
	float mid = stars(d, 180.0, star_density * 2.0);
	float small = stars(d, 420.0, star_density * 3.0) * 0.6;
	float dust = stars(d, 1100.0, 0.05 + band * 0.25) * (0.15 + band * 0.55);
	vec3 warm = vec3(1.0, 0.82, 0.6);
	vec3 cool = vec3(0.7, 0.85, 1.0);
	float temp = hash13(floor(d * 180.0) + 5.0);
	col += mix(cool, warm, step(0.7, temp)) * mid * 1.7 * veil;
	col += cool * small * 1.4 * veil;
	col += vec3(0.8, 0.86, 1.0) * dust * veil;
	col += mix(vec3(0.75, 0.9, 1.0), warm, step(0.6, hash13(floor(d * 70.0) + 2.0))) * bright * 4.0 * veil;

	col += moon(d, moon_a_dir, moon_a_size, vec3(0.78, 0.82, 0.9), vec3(0.8, 0.35, 0.5), 1.0);
	col += moon(d, moon_b_dir, moon_b_size, vec3(1.0, 0.62, 0.42), vec3(-0.6, 0.2, 0.75), 9.0);
	COLOR = col;
}
