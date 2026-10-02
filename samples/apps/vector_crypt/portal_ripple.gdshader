shader_type canvas_item;

// UVs are the oval on the wall, not window pixels. The polygon is the
// projected portal, so the rings stay on that surface when the view moves.
uniform float ripple_time = 0.0;
uniform vec4 tint : source_color = vec4(0.55, 0.95, 1.0, 1.0);

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float rings = 0.5 + 0.5 * sin(r * 28.0 - ripple_time * 4.5);
	float spoke = 0.5 + 0.5 * sin(atan(p.y, p.x) * 4.0 - ripple_time * 1.4);
	vec3 deep = vec3(0.03, 0.16, 0.38);
	vec3 hi = vec3(0.35, 0.78, 1.0);
	vec3 col = mix(deep, hi, rings * 0.85);
	col = mix(col, vec3(0.7, 0.95, 1.0), spoke * 0.25 * rings);
	COLOR = vec4(col, 1.0);
}
