shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform bool active = false;

void fragment() {
	float pulse = 0.8 + 0.2 * sin(TIME * 22.0 + UV.y * 30.0);
	vec3 tint = active ? vec3(1.0, 0.08, 0.025) : vec3(1.0, 0.48, 0.04);
	ALBEDO = tint * pulse * (active ? 3.0 : 1.3);
	if (active) {
		float core = pow(max(0.0, 1.0 - abs(UV.x * 2.0 - 1.0)), 6.0);
		ALBEDO += vec3(1.0, 0.8, 0.55) * core * 3.0;
	}
	ALPHA = active ? 0.9 : 0.5;
}
