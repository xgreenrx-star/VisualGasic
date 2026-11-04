shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

// Ceiling drips (MultiMesh): each instance swells at the roof, then falls and stretches.
// INSTANCE_CUSTOM: x phase, y cycles per second.
uniform float top = 59.6;
uniform float floor_y = 6.0;
varying float falling;

void vertex() {
	float cyc = fract(TIME * INSTANCE_CUSTOM.y + INSTANCE_CUSTOM.x);
	float fall = clamp((cyc - 0.72) / 0.28, 0.0, 1.0);
	falling = fall;
	VERTEX.y *= mix(0.25, 3.0, fall);
	VERTEX.y += mix(top, floor_y, fall * fall);
	VERTEX.xz *= mix(1.6, 0.8, fall);
}

void fragment() {
	ALBEDO = vec3(0.45, 0.75, 1.0) * (0.12 + 0.45 * falling);
}
