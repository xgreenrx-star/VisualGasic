shader_type canvas_item;
render_mode unshaded;

uniform float travel = 0.0;
uniform float rush : hint_range(0.0, 1.0) = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float bank = 0.0;

float hash(float p) {
	return fract(sin(p * 127.1) * 43758.5453);
}

void fragment() {
	vec2 p = (UV - vec2(0.5, 0.48)) * vec2(1.78, 1.0);
	p.x += bank * p.y * 0.12;
	float radius = max(length(p), 0.001);
	float angle = atan(p.y, p.x) + 3.14159265;
	float lane = floor(angle * 20.0);
	float seed = hash(lane + 11.0);
	float cross_line = abs(fract(angle * 20.0) - mix(0.15, 0.85, seed));
	float aa = max(fwidth(angle * 20.0), 0.015);
	float narrow = 1.0 - smoothstep(0.008, 0.008 + aa, cross_line);
	// Log radius gives an outward perspective rush, driven by travelled metres.
	float depth = fract(log(radius) * 0.65 - travel * 0.007 + seed * 13.0);
	float streak = smoothstep(0.6 - rush * 0.16, 0.65, depth) * (1.0 - smoothstep(0.9, 1.0, depth));
	streak *= narrow * step(0.28, seed);

	float dust_lane = floor(angle * 47.0);
	float dust_seed = hash(dust_lane + 79.0);
	float dust_depth = fract(log(radius) * 1.3 - travel * 0.011 + dust_seed * 19.0);
	float dust_width = abs(fract(angle * 47.0) - mix(0.12, 0.88, dust_seed));
	float dust = (1.0 - smoothstep(0.025, 0.025 + max(fwidth(angle * 47.0), 0.02), dust_width));
	dust *= smoothstep(0.88, 0.93, dust_depth) * (1.0 - smoothstep(0.96, 1.0, dust_depth));
	float clear_center = smoothstep(0.18, 0.46, radius);
	float edge = 1.0 - smoothstep(0.92, 1.08, radius);
	float mist = sin(angle * 5.0 + travel * 0.0013 + radius * 17.0) * 0.5 + 0.5;
	float fog = sin(p.x * 9.0 + p.y * 7.0 - travel * 0.0017) * sin(p.x * 4.0 - p.y * 11.0 + travel * 0.0021);
	float haze = pow(mist, 8.0) * 0.055 * smoothstep(0.3, 0.8, radius);
	haze += smoothstep(0.15, 0.9, fog) * 0.1 * smoothstep(0.25, 0.65, radius);
	vec3 tint = mix(vec3(0.24, 0.62, 0.74), vec3(0.75, 0.53, 0.28), dust_seed * 0.4);
	float alpha = (streak * (0.12 + rush * 0.3) + dust * 0.4 + haze) * clear_center * edge * strength;
	COLOR = vec4(tint, alpha);
}
