shader_type canvas_item;
uniform sampler2D halo_texture : filter_linear;
uniform float glow_amount = 0.65;
uniform float film_time = 0.0;
void fragment() {
	vec3 source = texture(TEXTURE, UV).rgb;
	vec3 halo = texture(halo_texture, UV).rgb;
	vec3 color = source + halo * glow_amount;
	float vignette = 1.0 - 0.18 * dot(UV - vec2(0.5), UV - vec2(0.5));
	float grain = fract(sin(dot(floor(UV * vec2(960.0, 540.0)), vec2(12.9898, 78.233)) + film_time) * 43758.5453);
	color = color * vignette + (grain - 0.5) * 0.006;
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
