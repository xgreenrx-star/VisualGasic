shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float pulse = 0.0;
void fragment() {
	ALBEDO = vec3(pulse, 0.2, 0.8);
}
