shader_type canvas_item;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 bloom = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.78539816;
		vec2 direction = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE;
		vec3 near_color = texture(TEXTURE, UV + direction * 2.0).rgb;
		vec3 far_color = texture(TEXTURE, UV + direction * 5.0).rgb;
		bloom += max(near_color - vec3(0.2), vec3(0.0)) * 0.065;
		bloom += max(far_color - vec3(0.2), vec3(0.0)) * 0.035;
	}
	COLOR = vec4(source.rgb + bloom, 1.0);
}
