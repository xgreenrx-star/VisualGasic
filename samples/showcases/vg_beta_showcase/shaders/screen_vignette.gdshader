shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.008, 0.012, 0.024, 1.0);
uniform float inner : hint_range(0.0, 1.0) = 0.38;
uniform float outer : hint_range(0.0, 1.5) = 0.98;
uniform float strength : hint_range(0.0, 1.0) = 0.94;
uniform float aspect : hint_range(0.5, 2.5) = 1.777;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	uv.x *= aspect;
	float dist = length(uv) * 2.0;
	float v = smoothstep(inner, outer, dist);
	COLOR = vec4(tint.rgb, tint.a * v * strength);
}
