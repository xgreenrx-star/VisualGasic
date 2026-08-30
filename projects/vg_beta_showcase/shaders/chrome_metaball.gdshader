shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float u_blend : hint_range(0.0, 1.0) = 1.0;

const int MAX_STEPS = 96;
const float MAX_DIST = 24.0;
const float SURF_EPS = 0.0008;

varying vec3 v_world;

float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

float sd_sphere(vec3 p, float r) {
	return length(p) - r;
}

float mapScene(vec3 p) {
	float core = sd_sphere(p, 1.45 + sin(TIME * 2.0) * 0.18);

	vec3 orbit_pos1 = p - vec3(sin(TIME * 1.5) * 2.0, cos(TIME * 1.1) * 1.15, sin(TIME * 0.7) * 0.35);
	float drop1 = sd_sphere(orbit_pos1, 0.68);

	vec3 orbit_pos2 = p - vec3(cos(TIME * 1.3) * 0.4, sin(TIME * 2.1) * 1.75, cos(TIME * 1.8) * 2.0);
	float drop2 = sd_sphere(orbit_pos2, 0.58);

	return smin(core, smin(drop1, drop2, 1.15), 1.15);
}

vec3 calc_normal(vec3 p) {
	vec2 e = vec2(0.0008, 0.0);
	return normalize(vec3(
		mapScene(p + e.xyy) - mapScene(p - e.xyy),
		mapScene(p + e.yxy) - mapScene(p - e.yxy),
		mapScene(p + e.yyx) - mapScene(p - e.yyx)
	));
}

float hash3(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float sky_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Match the space sky: gradient + soft nebula + sparse star glints (no high-freq grid).
vec3 sampleSpaceReflection(vec3 rd) {
	vec3 dir = normalize(rd);
	vec3 col = mix(vec3(0.002, 0.004, 0.016), vec3(0.035, 0.06, 0.16), dir.y * 0.5 + 0.5);

	float neb = sky_noise(dir.xz * 2.2 + vec2(TIME * 0.006, TIME * 0.004));
	neb += sky_noise(dir.xy * 1.6 - vec2(TIME * 0.005, 0.0)) * 0.55;
	col += vec3(0.08, 0.05, 0.14) * neb * 0.32;

	float stars_a = step(0.9983, hash3(floor(dir * 520.0)));
	float stars_b = step(0.9991, hash3(floor(dir * 880.0 + 17.0)));
	col += vec3(0.88, 0.94, 1.0) * (stars_a + stars_b * 0.5) * 0.75;

	return col;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 ro = CAMERA_POSITION_WORLD;
	vec3 rd = normalize(v_world - ro);
	ro = (inverse(MODEL_MATRIX) * vec4(ro, 1.0)).xyz;
	rd = normalize((inverse(MODEL_MATRIX) * vec4(rd, 0.0)).xyz);

	float t_march = 0.01;
	bool hit = false;
	vec3 p;

	for (int i = 0; i < MAX_STEPS; i++) {
		p = ro + rd * t_march;
		float d = mapScene(p);
		if (d < SURF_EPS) {
			hit = true;
			break;
		}
		t_march += max(d * 0.85, 0.004);
		if (t_march > MAX_DIST) {
			break;
		}
	}

	if (!hit) {
		discard;
	}

	vec3 normal = calc_normal(p);
	vec3 view_dir = -rd;
	vec3 refl = reflect(rd, normal);

	vec3 sky_refl = sampleSpaceReflection(refl);

	// Slow liquid sheen — low frequency so it reads as mercury, not checkerboard.
	float sheen_a = sin(refl.x * 2.2 + TIME * 0.45 + refl.z * 1.1) * 0.5 + 0.5;
	float sheen_b = sin(refl.y * 1.8 - TIME * 0.35) * 0.5 + 0.5;
	float sheen = smoothstep(0.2, 0.92, sheen_a * sheen_b);
	vec3 chrome = mix(sky_refl * 0.9, vec3(0.94, 0.97, 1.0), sheen * 0.22);

	vec3 light_dir = normalize(vec3(0.4, 0.82, 0.38));
	vec3 half_dir = normalize(light_dir + view_dir);
	float spec_tight = pow(max(dot(normal, half_dir), 0.0), 56.0);
	float spec_broad = pow(max(dot(normal, half_dir), 0.0), 10.0);
	chrome += vec3(0.82, 0.92, 1.0) * spec_tight * 0.55;
	chrome += vec3(0.28, 0.38, 0.55) * spec_broad * 0.18;

	vec3 rim_light = normalize(vec3(-0.55, 0.25, -0.72));
	float rim_spec = pow(max(dot(normal, normalize(rim_light + view_dir)), 0.0), 24.0);
	chrome += vec3(0.45, 0.62, 0.95) * rim_spec * 0.12;

	float fresnel = pow(1.0 - clamp(dot(normal, view_dir), 0.0, 1.0), 3.2);
	vec3 col = chrome + vec3(0.16, 0.36, 0.88) * fresnel * 0.42;

	col *= u_blend;
	ALBEDO = col;
	EMISSION = col * 0.22;
}
