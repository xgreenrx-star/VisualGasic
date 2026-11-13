shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D noise_tex : source_color, repeat_enable;
uniform float time = 0.0;
uniform float density = 0.15;
uniform vec3 tint = vec3(0.62, 0.22, 1.0);

void fragment() {
	vec2 uv = UV * 2.0 + vec2(time * 0.02, time * 0.01);
	float n = texture(noise_tex, uv).r;
	float a = n * density;
	ALBEDO = tint * n;
	EMISSION = tint * n * 0.4;
	ALPHA = a;
}
