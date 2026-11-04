shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

// B13 artificial sun: a red fusion lamp behind a hex lattice. heat 0 is the
// parked night ember, 1 is noon.
uniform float heat = 1.0;
varying vec3 local_point;

void vertex() {
	local_point = VERTEX;
}

void fragment() {
	vec3 p = normalize(local_point);
	vec2 uv = vec2(atan(p.z, p.x) * 3.0, p.y * 6.0);
	vec2 a = mod(uv, vec2(1.0, 1.732)) - vec2(0.5, 0.866);
	vec2 b = mod(uv - vec2(0.5, 0.866), vec2(1.0, 1.732)) - vec2(0.5, 0.866);
	float cell = min(dot(a, a), dot(b, b));
	float lattice = smoothstep(0.17, 0.2, cell);
	float boil = 0.75 + 0.25 * sin(p.x * 13.0 + TIME * 1.7) * sin(p.y * 11.0 - TIME * 1.3);
	vec3 core = mix(vec3(1.0, 0.18, 0.06), vec3(1.0, 0.62, 0.3), boil * 0.5);
	float rim = pow(1.0 - abs(dot(NORMAL, vec3(0.0, 0.0, 1.0))), 2.0);
	vec3 col = core * boil * (1.0 - lattice * 0.55) + vec3(1.0, 0.3, 0.1) * rim * 0.6;
	ALBEDO = col * mix(0.08, 1.8, clamp(heat, 0.0, 1.0));
}
