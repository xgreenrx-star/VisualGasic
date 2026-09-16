shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 0.02) = 0.003;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float ab = strength * (1.0 + pulse * 2.5);
	vec3 col;
	col.r = texture(screen_texture, uv + vec2(ab, 0.0)).r;
	col.g = texture(screen_texture, uv).g;
	col.b = texture(screen_texture, uv - vec2(ab, 0.0)).b;
	COLOR = vec4(col, 1.0);
}
