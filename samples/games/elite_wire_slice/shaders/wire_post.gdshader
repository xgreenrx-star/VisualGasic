shader_type canvas_item;

uniform float bloom : hint_range(0.0, 2.0) = 0.45;
uniform float scanline : hint_range(0.0, 1.0) = 0.12;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
uniform float aberration : hint_range(0.0, 0.02) = 0.0008;
uniform float pulse : hint_range(0.0, 2.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	vec2 px = TEXTURE_PIXEL_SIZE;
	float ab = aberration * (1.0 + pulse * 2.0);

	vec3 col;
	col.r = texture(TEXTURE, uv + vec2(ab, 0.0)).r;
	col.g = texture(TEXTURE, uv).g;
	col.b = texture(TEXTURE, uv - vec2(ab, 0.0)).b;

	vec3 acc = vec3(0.0);
	acc += texture(TEXTURE, uv + vec2(px.x * 1.5, 0.0)).rgb;
	acc += texture(TEXTURE, uv - vec2(px.x * 1.5, 0.0)).rgb;
	acc += texture(TEXTURE, uv + vec2(0.0, px.y * 1.5)).rgb;
	acc += texture(TEXTURE, uv - vec2(0.0, px.y * 1.5)).rgb;
	acc *= 0.25;
	vec3 glow = max(acc - vec3(0.08), vec3(0.0));
	col += glow * (bloom + pulse * 0.45);

	float line = sin(uv.y / px.y * 0.9);
	col *= 1.0 - scanline * 0.38 * (0.5 + 0.5 * line);

	vec2 q = uv - vec2(0.5);
	float vig = dot(q, q);
	col *= 1.0 - vignette * smoothstep(0.12, 0.82, vig);
	col += vec3(0.012, 0.02, 0.045) * (1.0 - vig);

	COLOR = vec4(col, 1.0);
}
