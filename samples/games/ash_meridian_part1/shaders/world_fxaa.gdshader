shader_type canvas_item;
render_mode unshaded;

float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	vec4 center = texture(TEXTURE, UV);
	vec3 nw = texture(TEXTURE, UV + pixel * vec2(-1.0, -1.0)).rgb;
	vec3 ne = texture(TEXTURE, UV + pixel * vec2(1.0, -1.0)).rgb;
	vec3 sw = texture(TEXTURE, UV + pixel * vec2(-1.0, 1.0)).rgb;
	vec3 se = texture(TEXTURE, UV + pixel * vec2(1.0, 1.0)).rgb;
	float c = luminance(center.rgb);
	float a = luminance(nw);
	float b = luminance(ne);
	float d = luminance(sw);
	float e = luminance(se);
	float low = min(c, min(min(a, b), min(d, e)));
	float high = max(c, max(max(a, b), max(d, e)));
	vec3 result = center.rgb;
	if (high - low > max(0.0312, high * 0.125)) {
		vec2 direction = vec2(d + e - a - b, a + d - b - e);
		float damping = max((a + b + d + e) * 0.03125, 0.0078125);
		direction /= min(abs(direction.x), abs(direction.y)) + damping;
		direction = clamp(direction, vec2(-8.0), vec2(8.0)) * pixel;
		vec3 inner = 0.5 * (texture(TEXTURE, UV - direction / 6.0).rgb + texture(TEXTURE, UV + direction / 6.0).rgb);
		vec3 outer = inner * 0.5 + 0.25 * (texture(TEXTURE, UV - direction * 0.5).rgb + texture(TEXTURE, UV + direction * 0.5).rgb);
		float candidate = luminance(outer);
		result = candidate < low || candidate > high ? inner : outer;
	}
	COLOR = vec4(result, center.a);
}
