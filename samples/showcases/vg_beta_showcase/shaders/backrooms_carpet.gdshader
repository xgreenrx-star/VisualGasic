shader_type spatial;
render_mode diffuse_lambert;

uniform vec3 base_color : source_color = vec3(0.62, 0.52, 0.28);
uniform vec3 fleck_color : source_color = vec3(0.48, 0.40, 0.22);
uniform float tile_scale = 18.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV * tile_scale;
	vec2 cell = floor(uv);
	float fleck = step(0.82, hash21(cell));
	vec3 col = mix(base_color, fleck_color, fleck * 0.45);
	ALBEDO = col;
	ROUGHNESS = 0.98;
}
