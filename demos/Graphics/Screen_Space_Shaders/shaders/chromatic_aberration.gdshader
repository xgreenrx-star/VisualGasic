shader_type canvas_item;

// Chromatic aberration — splits RGB channels with a radial offset.
// Very popular "eye candy" effect in modern games.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float aberration_amount : hint_range(0.0, 0.02) = 0.005;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = vec2(0.5, 0.5);
	vec2 dir = uv - center;
	float dist = length(dir);

	// Offset each channel differently based on distance from center.
	float r = textureLod(screen_texture, uv + dir * aberration_amount * dist, 0.0).r;
	float g = textureLod(screen_texture, uv, 0.0).g;
	float b = textureLod(screen_texture, uv - dir * aberration_amount * dist, 0.0).b;

	COLOR.rgb = vec3(r, g, b);
}
