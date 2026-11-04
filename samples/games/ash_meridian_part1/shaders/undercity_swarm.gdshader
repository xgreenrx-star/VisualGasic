shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled, skip_vertex_transform;

// A fly swarm around a surveillance camera (MultiMesh of tiny quads around the origin).
// Each speck orbits on its own wobbling path; the swarm bursts outward when scatter rises.
// A few are not flies at all: their red pinprick eyes catch the light.
uniform float scatter = 0.0;
varying float eye;

void vertex() {
	float s = INSTANCE_CUSTOM.x * 6.2831;
	float r = 0.6 + INSTANCE_CUSTOM.y * 1.4 + scatter * 5.0 * INSTANCE_CUSTOM.y;
	float sp = 2.0 + INSTANCE_CUSTOM.z * 3.0;
	vec3 c = vec3(cos(TIME * sp + s) * r, sin(TIME * sp * 1.3 + s * 2.0) * 0.6 + sin(TIME * 0.7 + s) * 0.4 + scatter * 2.0 * INSTANCE_CUSTOM.z, sin(TIME * sp * 0.9 + s) * r);
	c += vec3(sin(TIME * 11.0 + s * 5.0), cos(TIME * 13.0 + s * 3.0), sin(TIME * 9.0 + s * 7.0)) * 0.08;
	eye = step(0.8, INSTANCE_CUSTOM.w);
	vec3 centre = (MODEL_MATRIX * vec4(c, 1.0)).xyz;
	vec3 vp = (VIEW_MATRIX * vec4(centre, 1.0)).xyz;
	VERTEX = vp + vec3(VERTEX.x, VERTEX.y, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float d = length(UV - 0.5);
	if (d > 0.5) discard;
	vec3 col = vec3(0.012, 0.012, 0.014);
	if (eye > 0.5 && d < 0.22) col = vec3(1.0, 0.04, 0.02) * (0.6 + 0.4 * sin(TIME * 17.0));
	ALBEDO = col;
}
