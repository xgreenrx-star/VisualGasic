shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec3 beam_color = vec3(1.0, 0.18, 0.72);
uniform float energy = 0.0;
uniform float time = 0.0;

void fragment() {
	float core = pow(max(0.0, sin(UV.x * 3.141593)), 2.0);
	float fade = smoothstep(0.0, 0.15, UV.y) * (1.0 - UV.y * 0.7);
	vec3 color = 0.5 + 0.5 * cos(vec3(0.0, 2.1, 4.2) + time * 0.5 + UV.y * 2.0);
	ALBEDO = mix(beam_color, color, 0.7) * energy;
	EMISSION = ALBEDO;
	ALPHA = clamp(energy * core * fade * 0.18, 0.0, 0.3);
}
