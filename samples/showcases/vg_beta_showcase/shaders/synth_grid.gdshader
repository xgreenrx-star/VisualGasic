shader_type spatial;
render_mode unshaded, cull_back;

uniform float u_blend : hint_range(0.0, 1.0) = 1.0;
uniform float u_energy : hint_range(0.0, 1.0) = 0.0;
uniform vec4 u_ripples[4]; // xy = impact xz, z = age (s), w = strength

varying vec2 v_uv;
varying float v_wave;
varying vec2 v_xz;
varying float v_ripple_h;
varying float v_ripple_glow;

vec2 ripple_sample(vec2 xz, vec4 ripple) {
	if (ripple.w <= 0.001) {
		return vec2(0.0);
	}
	float age = ripple.z;
	if (age < 0.0 || age > 2.6) {
		return vec2(0.0);
	}

	vec2 center = ripple.xy;
	float dist = length(xz - center);
	float speed = 12.0;
	float band = dist - age * speed;
	float ring = sin(band * 1.4) * exp(-age * 1.05) * exp(-abs(band) * 0.24);
	float glow = abs(sin(band * 1.4)) * exp(-age * 1.35) * exp(-abs(band) * 0.32) * ripple.w;
	return vec2(ring * ripple.w * 3.2, glow);
}

vec2 ripple_sum(vec2 xz) {
	vec2 total = vec2(0.0);
	for (int i = 0; i < 4; i++) {
		total += ripple_sample(xz, u_ripples[i]);
	}
	return total;
}

void vertex() {
	v_uv = UV;
	vec3 p = VERTEX;
	v_xz = p.xz;
	float t = TIME;

	float wave = sin(p.x * 0.18 + t * 1.4) * 0.55
		+ sin(p.z * 0.14 - t * 1.1) * 0.45
		+ sin((p.x + p.z) * 0.09 + t * 0.7) * 0.35
		+ sin(length(p.xz) * 0.08 - t * 2.0) * 0.25;

	vec2 ripple = ripple_sum(p.xz);
	float ripple_h = ripple.x;
	v_ripple_glow = ripple.y;
	p.y += wave * 2.2 + ripple_h;
	VERTEX = p;
	v_wave = wave;
	v_ripple_h = ripple_h;
}

float gridLine(vec2 uv, float scale, float width) {
	vec2 g = fract(uv * scale);
	g = min(g, 1.0 - g);
	return smoothstep(width, 0.0, min(g.x, g.y));
}

void fragment() {
	float t = TIME;
	float h = v_wave + v_ripple_h * 0.35;

	vec3 colA = vec3(0.02, 0.85, 1.0);
	vec3 colB = vec3(1.0, 0.08, 0.82);
	vec3 base = mix(vec3(0.01, 0.015, 0.04), mix(colA, colB, sin(v_uv.x * 6.0 + v_uv.y * 5.0 + t) * 0.5 + 0.5), 0.35 + h * 0.12);

	float major = gridLine(v_uv, 24.0, 0.025);
	float minor = gridLine(v_uv, 96.0, 0.015);
	vec3 grid = mix(colA, colB, sin(t * 0.8 + v_uv.x * 2.4) * 0.5 + 0.5);
	base += grid * major * (0.85 + u_energy * 0.35);
	base += grid * minor * 0.25;

	float scan = sin((v_uv.y + t * 0.15) * 40.0) * 0.5 + 0.5;
	base += colA * scan * (0.06 + u_energy * 0.12);

	float horizon = exp(-abs(h + 0.2) * 1.8);
	base += vec3(0.15, 0.35, 0.9) * horizon * (0.35 + u_energy * 0.25);

	vec3 splash_col = mix(colA, vec3(1.0, 0.96, 0.88), 0.45);
	base += splash_col * v_ripple_glow * 1.35;

	base *= u_blend;
	ALBEDO = base;
	float beat = pow(max(0.0, sin(t * 2.1 * 6.2831853)), 2.0);
	EMISSION = base * (0.65 + u_energy * 0.25 + beat * 0.1) + splash_col * v_ripple_glow * 2.2;
}
