shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

// Camera-facing corona for the B13 sun.
uniform float heat = 1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float rays = 0.8 + 0.2 * sin(atan(q.y, q.x) * 14.0 + TIME * 0.6);
	float glow = pow(max(1.0 - r, 0.0), 2.2) * rays;
	ALBEDO = vec3(1.0, 0.22, 0.07) * glow * 1.4 * clamp(heat, 0.0, 1.0);
}
