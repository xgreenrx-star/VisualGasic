shader_type canvas_item;
render_mode unshaded;

// Screen pass for the vector chambers. Bright edges bloom, and the
// picture jitters by a fraction of a pixel the way a vector monitor does.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float flicker : hint_range(0.0, 1.0) = 0.85;
uniform float bloom : hint_range(0.0, 1.5) = 0.5;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	float t = TIME;
	// The picture bends, then locks flat. No color wash.
	float wake = clamp(1.0 - t / 0.7, 0.0, 1.0);
	wake = wake * wake;
	float jitter = sin(t * 53.0) * sin(t * 17.0);
	float scan = sin(t * 37.0 + SCREEN_UV.y * 90.0);
	vec2 c = SCREEN_UV - vec2(0.5);
	vec2 uv = SCREEN_UV;
	uv.x += sin(c.y * 8.0 + t * 12.0) * c.y * 0.28 * wake;
	uv.y += sin(c.x * 6.0 - t * 10.0) * c.x * 0.16 * wake;
	uv.x += c.x * sin(c.y * 10.0) * 0.2 * wake;
	uv += vec2(jitter, scan * 0.35) * px * flicker;

	vec3 col = texture(screen_tex, uv).rgb;
	// Tight neighbor sample — keeps cores sharp while still banding hot neon.
	vec3 around = texture(screen_tex, uv + vec2(px.x * 1.5, 0.0)).rgb;
	around += texture(screen_tex, uv + vec2(-px.x * 1.5, 0.0)).rgb;
	around += texture(screen_tex, uv + vec2(0.0, px.y * 1.5)).rgb;
	around += texture(screen_tex, uv + vec2(0.0, -px.y * 1.5)).rgb;
	around *= 0.25;
	vec3 hot = max(around - vec3(0.62), vec3(0.0));
	float pulse = 1.0 + 0.025 * sin(t * 61.0) * flicker;
	COLOR = vec4((col * 1.28 + hot * bloom * 0.7) * pulse, 1.0);
}
