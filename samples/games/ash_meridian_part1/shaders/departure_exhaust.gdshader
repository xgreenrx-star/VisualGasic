shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;

uniform float clock = 0.0;

void fragment() {
	float along = UV.y;
	float radius = mix(0.85, 0.06, along);
	float across = abs(UV.x * 2.0 - 1.0) / radius;
	float edge = 1.0 - smoothstep(0.05, 1.0, across);
	float fade = (1.0 - smoothstep(0.05, 1.0, along)) * smoothstep(0.0, 0.06, along);
	float shimmer = 0.94 + 0.06 * sin(clock * 19.0 - along * 12.0);
	float core = exp(-across * across * 12.0) * (1.0 - along);
	ALBEDO = mix(vec3(0.8, 0.27, 0.06), vec3(1.0, 0.85, 0.53), core);
	ALPHA = edge * fade * shimmer * 0.55;
}
