shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

// FEB eyes: sclera, iris and pupil from the eyeball normal (eyes look along -Z).
uniform vec4 sclera : source_color = vec4(0.86, 0.85, 0.82, 1.0);
uniform vec4 iris : source_color = vec4(0.18, 0.42, 0.5, 1.0);
uniform vec4 glow : source_color = vec4(0.25, 0.92, 1.0, 1.0);
uniform float glow_energy = 0.35;

varying vec3 nrm;

void vertex() {
	nrm = NORMAL;
}

void fragment() {
	float f = -normalize(nrm).z;
	float aa = max(fwidth(f), 1e-4);
	float in_iris = smoothstep(0.87 - aa, 0.87 + aa, f);
	float in_pupil = smoothstep(0.975 - aa, 0.975 + aa, f);
	vec3 c = mix(sclera.rgb, iris.rgb, in_iris);
	c = mix(c, vec3(0.01), in_pupil);
	ALBEDO = c;
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
	EMISSION = glow.rgb * glow_energy * in_iris * (1.0 - in_pupil);
}
