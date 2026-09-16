shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float u_blend : hint_range(0.0, 1.0) = 1.0;
uniform float u_pulse : hint_range(0.0, 1.0) = 0.0;
uniform float u_heat : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world_pos);
	float rim = pow(1.0 - clamp(dot(n, view_dir), 0.0, 1.0), 1.6);

	vec3 warm_core = vec3(1.0, 0.82, 0.38);
	vec3 warm_edge = vec3(1.0, 0.55, 0.12);
	vec3 white_hot = vec3(1.0, 0.99, 1.0);
	vec3 core = mix(warm_core, white_hot, u_heat);
	vec3 edge = mix(warm_edge, white_hot, u_heat);

	vec3 col = mix(edge, core, rim);
	float pulse_boost = 1.0 + u_pulse * 0.45;
	col *= pulse_boost;

	col *= u_blend;
	ALBEDO = col;
	EMISSION = col * (6.0 + u_heat * 10.0 + u_pulse * 3.0);
}
