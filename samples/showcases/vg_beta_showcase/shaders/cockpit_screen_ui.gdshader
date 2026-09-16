shader_type canvas_item;

uniform sampler2D screen_tex : filter_linear_mipmap, repeat_disable;
uniform float crt_mix : hint_range(0.0, 1.0) = 1.0;
uniform float scan : hint_range(0.0, 1.0) = 0.5;
uniform float glow : hint_range(0.0, 2.0) = 0.8;
uniform float preview_dim : hint_range(0.0, 1.0) = 0.88;

void fragment() {
	vec2 uv = UV;
	vec2 p = uv - 0.5;

	vec2 c = uv - 0.5;
	c *= 1.0 + dot(c, c) * 0.06 * crt_mix;
	vec2 sample_uv = c + 0.5;

	vec3 col = texture(screen_tex, sample_uv).rgb * preview_dim;

	if (crt_mix > 0.01) {
		float scanline = sin(sample_uv.y * 480.0 * 3.14159) * 0.5 + 0.5;
		col *= 1.0 - scan * 0.18 * scanline * crt_mix;
		col += vec3(0.03, 0.08, 0.06) * scanline * scan * crt_mix * 0.1;
		float ab = 0.003 * crt_mix;
		vec3 ab_col;
		ab_col.r = texture(screen_tex, sample_uv + vec2(ab, 0.0)).r;
		ab_col.g = col.g;
		ab_col.b = texture(screen_tex, sample_uv - vec2(ab, 0.0)).b;
		col = mix(col, ab_col, crt_mix * 0.65);
		float vig = smoothstep(0.55, 0.15, dot(p, p));
		col *= mix(1.0, vig, crt_mix * 0.35);
	}

	col += vec3(0.04, 0.12, 0.2) * glow * 0.08;
	COLOR = vec4(col, 1.0);
}
