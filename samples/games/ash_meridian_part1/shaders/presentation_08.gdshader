shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = COLOR.rgb * (0.5 + 0.5 * max(NORMAL.y, 0.0));
	ALPHA = smoothstep(0.0, 0.6, facing) * 0.5;
}
