shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float drift = TIME * 0.3;
	float patches = 0.5 + 0.25 * sin(p.x * 0.047 + drift) * cos(p.y * 0.039 - drift);
	patches += 0.12 * sin(p.x * 0.11 + p.y * 0.07);
	float edge = smoothstep(0.0, 0.16, UV.x) * smoothstep(0.0, 0.16, 1.0 - UV.x);
	edge *= smoothstep(0.0, 0.16, UV.y) * smoothstep(0.0, 0.16, 1.0 - UV.y);
	ALBEDO = mix(vec3(0.075, 0.10, 0.16), vec3(0.16, 0.21, 0.27), patches);
	ALPHA = edge * (0.12 + patches * 0.24);
}
