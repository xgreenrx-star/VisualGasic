shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// Shared water: street puddles and rectangular flood pools use the same reflection approximation.
uniform float power = 0.0;
uniform vec3 sun_color = vec3(0.0);
uniform bool rectangular = false;
uniform vec3 reflection_tint : source_color = vec3(1.0);
uniform vec3 room_tint : source_color = vec3(0.012, 0.018, 0.03);
uniform float electrical = 0.0;
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
	if (!rectangular && shape < 0.0) discard;
	float edge = rectangular ? 1.0 : smoothstep(0.0, 0.18, shape);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - world_point);
	float fres = pow(1.0 - clamp(eye.y, 0.0, 1.0), 3.0);
	vec2 along = normalize(eye.xz + vec2(0.0001));
	vec2 across = vec2(-along.y, along.x);
	vec2 r = world_point.xz + vec2(sin(world_point.z * 3.0 + TIME * 1.3), cos(world_point.x * 2.7 + TIME * 1.1)) * 0.04;
	float streak = pow(n2(vec2(dot(r, along) * 0.25, dot(r, across) * 2.2)), 3.0);
	float streak2 = pow(n2(vec2(dot(r, along) * 0.2 + 17.0, dot(r, across) * 1.4)), 4.0);
	vec3 reflected = COLOR.rgb * reflection_tint;
	vec3 neon = reflected * streak * 1.6 + reflected * streak2 * 0.65;
	float phase = length(fract(world_point.xz * 0.5) - 0.5) * 40.0 - TIME * 5.0;
	float ripple = 0.85 + 0.15 * sin(phase) * (1.0 - smoothstep(0.5, 3.0, fwidth(phase)));
	vec3 col = room_tint * (0.6 + fres) + neon * (0.12 + 0.88 * power) * ripple * (0.35 + 0.65 * fres);
	col += sun_color * fres * 0.35;
	float arc = pow(max(0.0, sin(world_point.x * 2.0 + world_point.z * 1.4 + TIME * 12.0)), 24.0);
	col += vec3(0.35, 0.65, 1.0) * arc * electrical * 0.35;
	ALBEDO = col;
	ALPHA = edge * (0.7 + 0.25 * fres);
}
