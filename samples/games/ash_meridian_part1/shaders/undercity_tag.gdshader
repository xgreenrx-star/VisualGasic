shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

// Holographic graffiti: glyph strokes (vertex COLOR) projected off the boundary walls,
// self-powered, with scanlines and a stuttering projector. Scrolling tags fade out
// beyond a window (fade_a..fade_b along the wall axis, measured in world space).
uniform vec3 axis = vec3(1.0, 0.0, 0.0);
uniform float centre = 0.0;
uniform float half_width = 100000.0;
uniform float seed = 0.0;
varying vec3 world_point;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float s = dot(world_point, axis) - centre;
	float win = smoothstep(half_width, half_width - 3.0, abs(s));
	float scan = 0.6 + 0.4 * sin(world_point.y * 70.0 - TIME * 6.0);
	float stutter = 0.75 + 0.25 * step(0.08, fract(sin(floor(TIME * 9.0) + seed) * 43758.5));
	ALBEDO = COLOR.rgb * 1.4 * scan * stutter * win;
}
