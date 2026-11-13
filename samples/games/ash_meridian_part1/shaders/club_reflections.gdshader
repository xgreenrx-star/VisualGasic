shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform float time = 0.0;
uniform float power = 0.0;
uniform float pulse = 0.0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.4, 1.0);
	float angle = time * 0.12;
	p = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * p;
	vec2 grid = p * 15.0 + vec2(time * 0.18, time * 0.09);
	vec2 cell = floor(grid);
	float seed = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	vec2 local = fract(grid) - vec2(0.5);
	float spot = 1.0 - smoothstep(0.06, 0.16, length(local));
	float visible = smoothstep(0.25, 0.7, seed);
	vec3 color = 0.55 + 0.45 * cos(vec3(0.0, 2.1, 4.2) + seed * 6.28 + time * 0.3);
	ALBEDO = color * (1.0 + pulse) * power;
	EMISSION = ALBEDO;
	ALPHA = spot * visible * power * 0.65;
}
