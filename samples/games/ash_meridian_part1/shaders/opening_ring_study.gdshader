shader_type canvas_item;
render_mode unshaded;

uniform float travel : hint_range(0.0, 1.0) = 0.25;

const float PLANET_RADIUS = 2.112;
const float RING_INNER_RADIUS = 3.6;
const float RING_OUTER_RADIUS = 4.8;
const float RING_HALF_HEIGHT = 0.15;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 a = i.xy + vec2(37.0, 17.0) * i.z;
	float n00 = mix(hash21(a), hash21(a + vec2(1.0, 0.0)), f.x);
	float n01 = mix(hash21(a + vec2(0.0, 1.0)), hash21(a + vec2(1.0)), f.x);
	a += vec2(37.0, 17.0);
	float n10 = mix(hash21(a), hash21(a + vec2(1.0, 0.0)), f.x);
	float n11 = mix(hash21(a + vec2(0.0, 1.0)), hash21(a + vec2(1.0)), f.x);
	return mix(mix(n00, n01, f.y), mix(n10, n11, f.y), f.z);
}

float terrain(vec3 p) {
	float sum = 0.0;
	float weight = 0.55;
	for (int i = 0; i < 5; i++) {
		sum += noise3(p) * weight;
		p = p * 2.04 + vec3(7.1, 3.8, 1.9);
		weight *= 0.5;
	}
	return sum;
}

float sphere_hit(vec3 ro, vec3 rd, float radius) {
	float b = dot(ro, rd);
	float c = dot(ro, ro) - radius * radius;
	float d = b * b - c;
	if (d < 0.0) return -1.0;
	float t = -b - sqrt(d);
	return t > 0.0 ? t : -1.0;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec3 ro = vec3(0.0, 8.0, 18.5 - travel * 2.0);
	vec3 forward = normalize(-ro);
	vec3 right = normalize(cross(forward, vec3(0.0, 1.0, 0.0)));
	vec3 up = cross(right, forward);
	vec3 rd = normalize(forward + uv.x * right * 0.40 - uv.y * up * 0.40);
	vec3 sun = normalize(vec3(-0.65, 0.55, 0.6));

	float nebula = terrain(rd * 4.0 + vec3(1.2, 4.0, 8.0));
	float band = exp(-pow((uv.y + uv.x * 0.19 + 0.1) * 2.6, 2.0));
	vec3 color = vec3(0.002, 0.005, 0.014)
		+ band * pow(nebula, 2.6) * vec3(0.035, 0.065, 0.105);
	vec2 star_uv = floor((uv + 2.0) * vec2(360.0, 300.0));
	float star_seed = hash21(star_uv);
	float star = smoothstep(0.997, 1.0, star_seed);
	color += star * vec3(0.55, 0.72, 0.85);

	float planet_t = sphere_hit(ro, rd, PLANET_RADIUS);
	if (planet_t > 0.0) {
		vec3 n = normalize(ro + rd * planet_t);
		float land = terrain(n * 7.0 + vec3(9.0, 3.0, 1.0));
		float erosion = terrain(n * 28.0 + vec3(4.0));
		vec3 rock = mix(vec3(0.075, 0.052, 0.047), vec3(0.38, 0.25, 0.17), smoothstep(0.28, 0.75, land));
		rock *= mix(0.68, 1.28, erosion);
		float light = max(dot(n, sun), 0.0);
		float rim = pow(1.0 - max(dot(-rd, n), 0.0), 3.0);
		color = rock * (0.055 + light * 0.95) + rim * vec3(0.09, 0.08, 0.055);
	}

	float ring_t = 100000.0;
	float side = 0.0;
	for (int i = 0; i < 2; i++) {
		float radius = i == 0 ? RING_OUTER_RADIUS : RING_INNER_RADIUS;
		float a = dot(rd.xz, rd.xz);
		float b = dot(ro.xz, rd.xz);
		float discriminant = b * b - a * (dot(ro.xz, ro.xz) - radius * radius);
		if (discriminant >= 0.0) {
			float near_t = (-b - sqrt(discriminant)) / a;
			float far_t = (-b + sqrt(discriminant)) / a;
			if (near_t > 0.0 && near_t < ring_t && abs(ro.y + rd.y * near_t) < RING_HALF_HEIGHT) {
				ring_t = near_t;
				side = 0.0;
			}
			if (far_t > 0.0 && far_t < ring_t && abs(ro.y + rd.y * far_t) < RING_HALF_HEIGHT) {
				ring_t = far_t;
				side = 0.0;
			}
		}
	}
	for (int i = 0; i < 2; i++) {
		float y = i == 0 ? -RING_HALF_HEIGHT : RING_HALF_HEIGHT;
		float t = (y - ro.y) / rd.y;
		float r = length((ro + rd * t).xz);
		if (t > 0.0 && t < ring_t && r > RING_INNER_RADIUS && r < RING_OUTER_RADIUS) {
			ring_t = t;
			side = 1.0;
		}
	}
	if (ring_t < 100000.0 && (planet_t < 0.0 || ring_t < planet_t)) {
		vec3 p = ro + rd * ring_t;
		float angle = atan(p.z, p.x) + 3.14159;
		float segment = floor(angle * 20.0);
		float band_y = floor((p.y + RING_HALF_HEIGHT) / (RING_HALF_HEIGHT * 2.0) * 9.0);
		float panel = hash21(vec2(segment, band_y));
		float seams = 1.0 - smoothstep(0.02, 0.07, fract(angle * 20.0));
		float horizontal = 1.0 - smoothstep(0.025, 0.08, fract((p.y + RING_HALF_HEIGHT) / (RING_HALF_HEIGHT * 2.0) * 9.0));
		vec3 metal = mix(vec3(0.035, 0.045, 0.065), vec3(0.14, 0.16, 0.18), panel);
		metal *= 0.55 + max(dot(normalize(vec3(p.x, 0.0, p.z)), sun), 0.0) * 0.8;
		metal *= 1.0 - max(seams, horizontal) * 0.55;
		float strip = 1.0 - smoothstep(0.012, 0.04, abs(p.y - RING_HALF_HEIGHT * 0.65));
		float lit = step(0.36, hash21(vec2(segment, 7.0)));
		metal += strip * lit * vec3(0.04, 0.42, 0.50);
		metal += side * vec3(0.035, 0.055, 0.06);
		color = metal;
	}

	float vignette = 1.0 - smoothstep(0.65, 2.0, length(uv)) * 0.38;
	color *= vignette;
	color = color / (color + vec3(1.0));
	COLOR = vec4(pow(color, vec3(0.4545)), 1.0);
}
