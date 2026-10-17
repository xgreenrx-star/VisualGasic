shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float warning_flash = 0.0;
uniform float yard_haze = 0.0;
varying vec3 world_point;
void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 surface_color = mix(COLOR.rgb, vec3(1.0, 0.07, 0.22), warning_flash * 0.65);
	float fog_distance = max(distance(CAMERA_POSITION_WORLD, world_point) - 28.0, 0.0) / 155.0;
	float fog = (1.0 - exp(-fog_distance * fog_distance)) * yard_haze;
	ALBEDO = mix(surface_color, vec3(0.18, 0.20, 0.29), fog);
}
