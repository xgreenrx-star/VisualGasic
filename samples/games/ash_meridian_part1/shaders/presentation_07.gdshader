shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float line_width = 1.6;
void vertex() {
	vec4 p = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 q = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX + NORMAL, 1.0);
	vec2 direction = (q.xy / max(q.w, 0.001) - p.xy / max(p.w, 0.001)) * vec2(960.0, 540.0);
	vec2 across = vec2(-direction.y, direction.x) / max(length(direction), 0.001);
	p.xy += across * UV.x * line_width / vec2(960.0, 540.0) * p.w;
	POSITION = p;
	POSITION.z += 0.00002 * POSITION.w;
}
void fragment() { ALBEDO = COLOR.rgb * 1.25; }
