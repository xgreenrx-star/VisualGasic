shader_type canvas_item;
render_mode unshaded;

uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform float clock = 0.0;
uniform float moving : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Sample the DATA texture around its center. reveal grows from zero to one.
	vec2 point = UV - vec2(0.5);
	float radius = length(point);
	float angle = (1.0 - reveal) * 9.0 * exp(-radius * 3.0);
	float c = cos(angle);
	float s = sin(angle);
	vec2 rotated = vec2(c * point.x - s * point.y, s * point.x + c * point.y);
	vec2 sample_uv = rotated / max(reveal, 0.025) + vec2(0.5);
	// Discard sampling coordinates outside the sprite, avoiding edge streaks.
	float inside = step(0.0, sample_uv.x) * step(sample_uv.x, 1.0)
		* step(0.0, sample_uv.y) * step(sample_uv.y, 1.0);
	vec4 pixel = texture(TEXTURE, sample_uv);
	pixel.rgb *= 1.0 + moving * 0.12 * sin(clock * 8.0);
	COLOR = vec4(pixel.rgb, pixel.a * inside * smoothstep(0.0, 0.08, reveal));
}
