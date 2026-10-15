shader_type canvas_item;
uniform vec2 direction = vec2(1.0, 0.0);
uniform bool threshold = false;
void fragment() {
	vec3 result = vec3(0.0);
	for (int i = -4; i <= 4; i++) {
		vec3 sample_color = texture(TEXTURE, UV + direction * TEXTURE_PIXEL_SIZE * float(i) * 1.8).rgb;
		if (threshold) {
			float peak = max(sample_color.r, max(sample_color.g, sample_color.b));
			sample_color *= smoothstep(0.48, 0.88, peak);
		}
		float weight = exp(-float(i * i) * 0.16);
		result += sample_color * weight / 4.38;
	}
	COLOR = vec4(result, 1.0);
}
