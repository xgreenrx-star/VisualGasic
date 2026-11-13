shader_type spatial;
render_mode unshaded, cull_back;

// Equirectangular shell. U scrolls with the beat clock; the mask keeps the poles dark.
uniform sampler2D albedo : source_color, repeat_enable;
uniform sampler2D emission_tex : source_color, repeat_enable;
uniform sampler2D mask_tex : source_color, repeat_enable;
uniform float spin = 0.0;
uniform float energy = 0.0;
uniform vec3 tint = vec3(0.62, 0.22, 1.0);

void fragment() {
	vec2 uv = vec2(fract(UV.x + spin), UV.y);
	vec3 mask = texture(mask_tex, uv).rgb;
	vec3 alb = texture(albedo, uv).rgb;
	float glint = pow(max(0.0, sin(mask.r * 80.0 + spin * 100.0)), 12.0);
	vec3 rainbow = 0.5 + 0.5 * cos(vec3(0.0, 2.1, 4.2) + mask.r * 6.28 + spin * 12.0);
	vec3 em = texture(emission_tex, uv).rgb * energy;
	em += rainbow * (mask.g * 0.35 + mask.b * 0.5 + glint * 0.45) * energy;
	float rim = pow(1.0 - max(0.0, dot(normalize(NORMAL), normalize(VIEW))), 3.0);
	em += (tint * rim * 0.65 + vec3(0.8, 0.9, 1.0) * glint * 0.3) * energy;
	ALBEDO = alb * (0.3 + energy * 0.4);
	EMISSION = em;
}
