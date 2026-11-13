shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.06, 0.08, 0.1, 1.0);
uniform float metalness : hint_range(0.0, 1.0) = 0.4;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.65;
varying vec3 local_point;

float grain(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void vertex() {
	local_point = VERTEX;
}

void fragment() {
	float fine = grain(floor(local_point * 850.0));
	float brushed = grain(floor(local_point * vec3(600.0, 6.0, 18.0)));
	float mottling = grain(floor(local_point * 12.0));
	ALBEDO = base_color.rgb * (0.95 + fine * 0.015 + brushed * 0.02 + mottling * 0.015);
	METALLIC = metalness;
	ROUGHNESS = clamp(surface_roughness + (fine - 0.5) * 0.02, 0.1, 1.0);
}
