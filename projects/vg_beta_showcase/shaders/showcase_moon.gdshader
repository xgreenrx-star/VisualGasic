shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform float u_blend : hint_range(0.0, 1.0) = 1.0;
uniform float u_pulse : hint_range(0.0, 1.0) = 0.0;
uniform float u_heat : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float moon_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = (UV - vec2(0.5)) * 2.0;
	float dist = length(uv);

	// Full lunar disk — opaque sphere silhouette; stars must not show through.
	float disk = 1.0 - smoothstep(0.915, 0.985, dist);
	if (disk < 0.001) {
		discard;
	}

	// Offset shadow circle = sun direction; unlit side stays on the disk.
	vec2 shadow_center = vec2(0.44, 0.02);
	float shadow = length(uv - shadow_center);
	float night = smoothstep(0.70, 0.60, shadow);
	float lit = disk * (1.0 - night);

	// Limb darkening toward the edge of the sphere.
	float limb = smoothstep(0.55, 0.94, dist);

	// Subtle mare / crater variation across the whole face.
	float surface = moon_noise(uv * 5.5 + vec2(0.2, 1.7));
	surface += moon_noise(uv * 11.0 + vec2(3.1, 0.4)) * 0.45;
	surface = surface * 0.5 + 0.5;

	vec3 lit_base = mix(vec3(0.78, 0.82, 0.9), vec3(0.95, 0.96, 0.98), surface);
	lit_base = mix(lit_base, vec3(1.0, 0.99, 0.96), u_heat);
	lit_base *= 1.0 - limb * 0.22;

	// Dark side: nearly black but with faint earthshine — still fully opaque.
	vec3 dark_base = vec3(0.012, 0.014, 0.022);
	dark_base += vec3(0.035, 0.042, 0.06) * (0.18 + u_pulse * 0.06);
	dark_base += vec3(0.025, 0.03, 0.045) * surface * night;

	// Soft terminator glow between lit and dark hemispheres.
	float terminator = smoothstep(0.52, 0.68, shadow) * smoothstep(0.86, 0.70, shadow) * disk;
	vec3 rim_col = vec3(0.42, 0.55, 0.78);

	vec3 col = lit_base * lit + dark_base * night;
	col += rim_col * terminator * 0.28;
	col *= 1.0 + u_pulse * 0.22;

	col *= u_blend;
	ALBEDO = col;
	float lit_glow = 4.2 + u_pulse * 3.0 + u_heat * 8.0;
	EMISSION = lit_base * lit * lit_glow * u_blend + dark_base * night * 0.06 * u_blend;
}
