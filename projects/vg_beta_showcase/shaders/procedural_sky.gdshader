shader_type sky;

uniform float u_mode : hint_range(0.0, 1.0) = 0.0;

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
	for (int i = 0; i < 5; i++) {
		v += noise(p) * amp;
		p *= 2.05;
		amp *= 0.5;
	}
	return v;
}

vec3 sky_space(vec3 dir) {
	vec3 col = mix(vec3(0.002, 0.004, 0.018), vec3(0.03, 0.05, 0.14), dir.y * 0.5 + 0.5);

	float neb = fbm(dir.xz * 2.4 + vec2(TIME * 0.01, 0.0));
	col += vec3(0.08, 0.04, 0.18) * neb * 0.35;

	float stars_a = hash3(floor(dir * 520.0));
	float stars_b = hash3(floor(dir * 880.0 + 17.0));
	float stars = step(0.9985, stars_a) + step(0.9993, stars_b) * 0.6;
	col += vec3(0.85, 0.92, 1.0) * stars * 0.75;

	return col;
}

vec3 sky_day(vec3 dir) {
	float y = dir.y;

	vec3 zenith = vec3(0.06, 0.38, 0.92);
	vec3 horizon = vec3(0.42, 0.68, 0.98);
	vec3 ground_haze = vec3(0.28, 0.32, 0.38);
	vec3 col = mix(horizon, zenith, smoothstep(0.0, 0.72, y));
	col = mix(ground_haze, col, smoothstep(-0.08, 0.18, y));

	if (y > 0.02) {
		vec2 cloud_uv = dir.xz / (y + 0.2);
		float c1 = fbm(cloud_uv * 1.6 + vec2(TIME * 0.012, 0.0));
		float c2 = fbm(cloud_uv * 3.2 + vec2(-TIME * 0.007, 2.3));
		float clouds = smoothstep(0.42, 0.7, c1 * 0.55 + c2 * 0.45);
		clouds *= smoothstep(0.04, 0.32, y);
		col = mix(col, vec3(1.0, 0.99, 0.97), clouds * 0.82);
	}

	vec3 sun_dir = normalize(vec3(0.45, 0.55, -0.55));
	float sun_dot = dot(dir, sun_dir);
	float sun_disc = smoothstep(0.9996, 0.9999, sun_dot);
	float sun_halo = pow(max(sun_dot, 0.0), 72.0);
	col += vec3(1.0, 0.97, 0.88) * sun_disc * 10.0;
	col += vec3(1.0, 0.78, 0.38) * sun_halo * 2.5;

	return col;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	COLOR = mix(sky_day(dir), sky_space(dir), u_mode);
}
