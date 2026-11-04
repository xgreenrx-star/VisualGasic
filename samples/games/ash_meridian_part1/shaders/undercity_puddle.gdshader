shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// B13 street puddles: a noisy blob per quad (UV 0..1) that fakes the city's reflection.
// Neon streaks smear toward the viewer and ripple; COLOR is the nearest sign's colour.
uniform float power = 0.0;
uniform vec3 sun_color = vec3(0.0);
varying vec3 world_point;

float h(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float shape = 1.0 - length(q) + (n2(world_point.xz * 0.9) - 0.5) * 0.8;
	if (shape < 0.0) discard;
	float edge = smoothstep(0.0, 0.18, shape);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - world_point);
	float fres = pow(1.0 - clamp(eye.y, 0.0, 1.0), 3.0);
	vec2 along = normalize(eye.xz + vec2(0.0001));
	vec2 across = vec2(-along.y, along.x);
	vec2 r = world_point.xz + vec2(sin(world_point.z * 3.0 + TIME * 1.3), cos(world_point.x * 2.7 + TIME * 1.1)) * 0.04;
	float streak = pow(n2(vec2(dot(r, along) * 0.25, dot(r, across) * 2.2)), 3.0);
	float streak2 = pow(n2(vec2(dot(r, along) * 0.2 + 17.0, dot(r, across) * 1.4)), 4.0);
	vec3 neon = COLOR.rgb * streak * 1.6 + COLOR.gbr * streak2 * 0.9;
	float ripple = 0.85 + 0.15 * sin(length(fract(world_point.xz * 0.5) - 0.5) * 40.0 - TIME * 5.0);
	vec3 col = vec3(0.006, 0.009, 0.016) + neon * (0.12 + 0.88 * power) * ripple * (0.35 + 0.65 * fres);
	col += sun_color * fres * 0.35;
	ALBEDO = col;
	ALPHA = edge * (0.7 + 0.25 * fres);
}
