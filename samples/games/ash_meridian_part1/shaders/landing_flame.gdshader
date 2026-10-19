shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);
	float along = UV.y;
	float width = smoothstep(1.0, 0.12, across * (0.22 + along * 1.7));
	float length_fade = smoothstep(1.0, 0.02, along);
	float core = smoothstep(0.5, 0.0, across) * smoothstep(0.4, 0.0, along);
	float flicker = 0.8 + 0.2 * sin(TIME * 34.0 + along * 16.0);
	vec3 hot = vec3(1.0, 0.94, 0.62);
	vec3 body = vec3(1.0, 0.32, 0.05);
	float glow = width * length_fade * flicker;
	ALBEDO = mix(body, hot, core) * glow * 2.2;
	ALPHA = glow;
}
