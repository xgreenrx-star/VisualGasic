shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

// Airborne dust (CPUParticles3D, billboarded). Specks are near-invisible in the dark and
// light up near holograms, screens, lamps and the sun: glow_p xyz + radius, glow_c rgb.
uniform int glow_n = 0;
uniform vec4 glow_p[8];
uniform vec4 glow_c[8];
varying vec3 world_point;

void vertex() {
	mat4 w = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * w;
	world_point = MODEL_MATRIX[3].xyz;
}

void fragment() {
	float d = length(UV - 0.5);
	if (d > 0.5) discard;
	vec3 col = vec3(0.02, 0.025, 0.03);
	for (int i = 0; i < glow_n; i++) {
		float k = 1.0 - clamp(distance(world_point, glow_p[i].xyz) / glow_p[i].w, 0.0, 1.0);
		col += glow_c[i].rgb * k * k * 0.9;
	}
	float tw = 0.7 + 0.3 * sin(TIME * 3.0 + world_point.x * 13.0 + world_point.z * 7.0);
	ALBEDO = col * smoothstep(0.5, 0.1, d) * tw * COLOR.a;
}
