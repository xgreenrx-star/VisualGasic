shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float alarm_time = 0.0;
void fragment() {
	float wave = sin(UV.x * 26.0 + alarm_time * 0.4) * sin(UV.y * 18.0 - alarm_time * 0.2);
	float edge = smoothstep(0.0, 0.15, UV.x) * smoothstep(0.0, 0.15, 1.0 - UV.x);
	ALBEDO = vec3(0.16, 0.35, 0.4);
	ALPHA = (0.12 + wave * 0.05) * edge;
}
