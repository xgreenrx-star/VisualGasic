shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float warning_flash = 0.0;
void fragment() {
	ALBEDO = mix(COLOR.rgb, vec3(1.0, 0.07, 0.22), warning_flash * 0.65);
}
