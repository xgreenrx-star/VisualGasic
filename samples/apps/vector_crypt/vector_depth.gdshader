// Applied to the DepthView MeshInstance3D (facility walls).
// Vertex COLOR comes from BuildDepthMesh. Bright verts emit; near-black
// verts stay dark so black fill quads occlude without glowing.
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
