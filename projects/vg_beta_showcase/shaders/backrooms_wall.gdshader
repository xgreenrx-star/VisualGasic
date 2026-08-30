shader_type spatial;
render_mode diffuse_lambert;

uniform vec3 base_color : source_color = vec3(0.86, 0.82, 0.52);
uniform vec3 stripe_color : source_color = vec3(0.78, 0.74, 0.46);
uniform float tile_scale = 6.0;
uniform float noise_strength = 0.04;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV * tile_scale;
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	float stripe = step(0.5, fract(cell.y * 0.5 + cell.x * 0.25));
	vec3 col = mix(base_color, stripe_color, stripe * 0.35);
	float n = hash21(cell + f * 0.7) * noise_strength;
	col *= 1.0 - n;
	ALBEDO = col;
	ROUGHNESS = 0.92;
}
