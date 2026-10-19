shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec3 cloud_lit : source_color = vec3(0.62, 0.70, 0.78);
uniform vec3 cloud_shade : source_color = vec3(0.10, 0.14, 0.20);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float weight = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		value += weight * noise(p);
		p = p * 2.07 + vec2(1.7, 9.2);
		weight *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float field = fbm(UV * vec2(3.2, 1.6) + NODE_POSITION_WORLD.zx * 0.004);
	float puff = smoothstep(0.42, 0.72, field);
	float body = smoothstep(1.05, 0.15, length(p * vec2(0.85, 1.35)));
	float edge = smoothstep(0.15, 0.85, field);
	ALPHA = puff * body * 0.72;
	ALBEDO = mix(cloud_shade, cloud_lit, edge) * COLOR.rgb;
}
