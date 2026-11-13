shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

float noise(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float smooth_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(noise(i), noise(i + vec2(1.0, 0.0)), f.x),
		mix(noise(i + vec2(0.0, 1.0)), noise(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float erosion = smooth_noise(p * 12.0) * 0.12 + smooth_noise(p * 35.0) * 0.04;
	float scar = 1.0 - smoothstep(0.15, 0.86, r + erosion);
	float grain = noise(floor(UV * 600.0));
	ALBEDO = mix(vec3(0.012, 0.009, 0.014), vec3(0.14, 0.065, 0.035), smoothstep(0.25, 0.6, r)) * (0.65 + grain * 0.35);
	ALPHA = clamp(scar * 1.5, 0.0, 0.94);
}
