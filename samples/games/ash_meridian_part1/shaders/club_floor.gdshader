shader_type spatial;
render_mode unshaded, cull_disabled;

// Section 0 is ripples. Section 2 adds a chase and a white downbeat strobe.
uniform sampler2D mask_tex : source_color, repeat_enable;
uniform float beat = 0.0;
uniform float section = 0.0;
uniform float strobe = 0.0;
uniform float time = 0.0;
uniform float power = 0.0;
uniform float pulse = 0.0;
uniform bool reduced = false;
uniform vec3 uv_col = vec3(0.62, 0.22, 1.0);
uniform vec3 mag = vec3(1.0, 0.18, 0.72);
uniform vec3 acid = vec3(0.55, 1.0, 0.25);

void fragment() {
	vec4 tiles = texture(mask_tex, UV * 1.5);
	float speed = reduced ? 0.6 : 2.0;
	float ripple = 0.5 + 0.5 * sin(length(UV - vec2(0.5)) * 28.0 - time * speed);
	float chase = 0.5 + 0.5 * sin(UV.x * 24.0 + UV.y * 12.0 - time * speed);
	vec3 col = uv_col * tiles.r * (0.25 + ripple);
	col += mag * tiles.g * (0.25 + chase);
	col += acid * tiles.b * (0.25 + 1.0 - ripple);
	col *= (0.65 + pulse * 0.65);
	col = mix(col, vec3(1.0), strobe * 0.5);
	col *= power;
	ALBEDO = col;
	EMISSION = col;
}
