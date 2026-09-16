shader_type canvas_item;

uniform float ripple_time : hint_range(0.0, 1000.0) = 0.0;
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.0;
uniform float banner_alpha : hint_range(0.0, 1.0) = 0.2;

void fragment() {
	vec2 uv = UV;
	float wave_x = sin(uv.y * 16.0 + ripple_time * 5.5) * ripple_strength * 0.014;
	float wave_y = sin(uv.x * 11.0 - ripple_time * 3.8) * ripple_strength * 0.009;
	vec2 offset = vec2(wave_x, wave_y);
	COLOR = texture(TEXTURE, uv + offset);
	COLOR.rgb *= 0.72;
	COLOR.a *= banner_alpha;
}
