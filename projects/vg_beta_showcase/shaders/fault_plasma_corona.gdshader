shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

uniform float u_blend : hint_range(0.0, 1.0) = 1.0;
uniform float u_bg_pulse : hint_range(0.0, 1.0) = 1.0;
uniform float explosion_factor : hint_range(0.0, 5.0) = 1.0;

varying vec3 v_normal;
varying vec3 v_world;

void vertex() {
	v_normal = NORMAL;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float pulse = (sin(TIME * 2.5) * 0.5 + 0.5) * explosion_factor;
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world);
	float fresnel = pow(1.0 - clamp(dot(normalize(v_normal), view_dir), 0.0, 1.0), 1.4);

	float plasma_a = sin(v_normal.x * 11.0 + TIME * 2.2) * cos(v_normal.y * 9.0 - TIME * 1.6);
	float plasma_b = sin(v_normal.z * 13.0 - TIME * 1.9 + v_normal.x * 4.0);
	float plasma = plasma_a * plasma_b * 0.5 + 0.5;
	plasma += noise(v_normal.xz * 6.0 + TIME * 0.4) * 0.4;

	vec3 hot = mix(vec3(1.0, 0.45, 0.05), vec3(1.0, 0.92, 0.4), plasma);
	vec3 cool = mix(vec3(0.7, 0.15, 1.0), vec3(0.2, 0.75, 1.0), plasma);
	vec3 col = mix(cool, hot, fresnel * 0.8 + pulse * 0.4);
	col *= 0.35 + fresnel * 0.65;
	col += hot * pulse * 0.25;

	col *= u_blend;
	float shell = mix(0.04, 1.0, u_bg_pulse);
	ALBEDO = col * shell;
	EMISSION = col * (1.2 + pulse * 2.8) * u_bg_pulse;
	ALPHA = mix(0.04, 0.88, u_bg_pulse) * u_blend;
}
