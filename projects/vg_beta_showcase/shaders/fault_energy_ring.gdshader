shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float u_blend : hint_range(0.0, 1.0) = 1.0;
uniform float explosion_factor : hint_range(0.0, 5.0) = 1.0;
uniform float u_phase : hint_range(0.0, 6.28) = 0.0;

varying vec2 v_uv;

void vertex() {
	v_uv = UV;
}

void fragment() {
	float pulse = (sin(TIME * 2.5 + u_phase) * 0.5 + 0.5) * explosion_factor;
	float flow = sin(v_uv.x * 48.0 - TIME * 10.0 + u_phase * 4.0) * 0.5 + 0.5;
	float arc = smoothstep(0.42, 0.0, abs(fract(v_uv.x * 14.0 - TIME * 3.0 + u_phase) - 0.5));
	float band = sin(v_uv.y * 30.0 + TIME * 6.0) * 0.5 + 0.5;

	vec3 cyan = vec3(0.15, 0.95, 1.0);
	vec3 orange = vec3(1.0, 0.48, 0.08);
	vec3 white = vec3(1.0, 0.96, 0.85);
	vec3 col = mix(cyan, orange, flow);
	col = mix(col, white, arc * 0.85);
	col += white * band * arc * 0.35;
	col *= 0.55 + pulse * 0.55 + explosion_factor * 0.15;

	col *= u_blend;
	ALBEDO = col;
	EMISSION = col * (5.0 + pulse * 3.0);
}
