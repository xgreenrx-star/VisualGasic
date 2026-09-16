shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float glow : hint_range(0.0, 2.0) = 1.0;
uniform float approach : hint_range(0.0, 1.0) = 0.0;
uniform float time_offset : hint_range(0.0, 100.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float land_mask(vec3 n) {
	float lat = abs(n.y);
	vec2 uv = vec2(atan(n.x, n.z) / 6.28318, n.y) * vec2(3.5, 2.2);
	float f = noise(uv * 4.0 + vec2(time_offset * 0.02, 0.0));
	f += noise(uv * 9.0) * 0.45;
	return smoothstep(0.46 + lat * 0.18, 0.62 + lat * 0.12, f);
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float fresnel = pow(1.0 - max(dot(n, v), 0.0), 2.8);

	float land = land_mask(n);
	vec3 ocean = vec3(0.02, 0.14, 0.32);
	vec3 terrain = mix(vec3(0.08, 0.28, 0.12), vec3(0.22, 0.42, 0.18), noise(n.xz * 8.0));
	vec3 clouds = vec3(0.92, 0.95, 1.0) * smoothstep(0.72, 0.92, noise(n.xz * 12.0 + 4.0)) * 0.35;
	vec3 surface = mix(ocean, terrain, land) + clouds * land;

	vec3 day_side = vec3(1.0, 0.92, 0.78);
	vec3 lit = surface * (0.35 + max(dot(n, normalize(vec3(0.4, 0.35, -0.85))), 0.0) * 0.85);

	vec3 atmo_warm = vec3(1.0, 0.52, 0.18);
	vec3 atmo_cool = vec3(0.35, 0.72, 1.0);
	vec3 rim = mix(atmo_cool, atmo_warm, approach) * fresnel * (0.85 + glow * 0.4);

	vec3 col = lit + rim;
	col += rim * approach * 0.55;
	EMISSION = rim * (0.25 + approach * 0.35);
	ALBEDO = col;
}
