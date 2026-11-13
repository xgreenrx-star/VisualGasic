shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform float mouth = 0.0;
uniform float clock = 0.0;
uniform bool wire = false;

void vertex() {
	float jaw = smoothstep(0.65, 0.9, UV.y);
	VERTEX.y -= mouth * jaw * 0.18;
}

void fragment() {
	float scan = 0.75 + 0.25 * sin(UV.y * 700.0 + clock * 1.5);
	vec3 color = mix(vec3(0.12, 0.4, 0.5), vec3(0.55, 0.94, 1.0), float(wire));
	ALBEDO = color;
	EMISSION = color * scan;
	ALPHA = (wire ? 0.8 : 0.18) * scan;
}
