shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

void fragment() {
	vec3 c = COLOR.rgb;
	float lum = max(c.r, max(c.g, c.b));
	if (lum > 0.02) {
		// Hot neon cores so Godot glow bands the wireframes like Paradox Vector.
		ALBEDO = c;
		EMISSION = c * (0.85 + lum * 0.9);
	} else {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(0.0);
	}
}
